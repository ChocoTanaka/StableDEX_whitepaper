import 'dart:math';

double rate_JPYC_pol_0 = 12.00; //1200000
double rate_USDC_pol_0 = 0.076; //7600
double rate_EURC_pol_0 = 0.066; //6600

double rate_JPYC_USDC_0 = 159.22; //1592200
double rate_USDC_USDC_0 = 1.0; //10000
double rate_EURC_USDC_0 = 0.87; //8700

double rate_IN_OUT(double rateA , double rateB){

  bool p_m = Random().nextBool();

  double rate = p_m ? (rateB / rateA) * (1 + 0.03 * Random().nextDouble()) : (rateB / rateA) * (1 - 0.03 * Random().nextDouble());

  return rate;
}


double reserve_USDC = 1000;
double reserve_JPYC = 163000;

/// 手数料関数モデルの定義
enum FeeFunctionType {
  linear,     // 線形: diff * multiplier
  quadratic,  // 2次関数: (diff^2) * multiplier （急激な偏りに強くブレーキ）
  exponential // 指数関数的ブレーキ
}



/// ステーブルコイン単体（Single-sided Reserve）のプール情報
class StablecoinPool {
  final String symbol;
  double reserve; // 準備高 (Pool)

  double fees = 0;

  double rate;

  StablecoinPool({required this.symbol, required this.reserve, required this.fees, required this.rate});
}





class SimulationEngine {
  final StablecoinPool poolA; // USDC
  final StablecoinPool poolB; // JPYC
  final StablecoinPool poolC; // EURC
  final double baseFeeRate;

  final FeeFunctionType feeType;
  final double feeMultiplier; // 手数料関数の感度パラメータ

  // 累積統計データ
  double totalBaseFeeInA = 0.0;
  double totalBaseFeeInB = 0.0;
  double totalBaseFeeInC = 0.0;
  double totalSkewFeeInA = 0.0; // プールAへ還元された歪み手数料
  double totalSkewFeeInB = 0.0; // プールBへ還元された歪み手数料
  double totalSkewFeeInC = 0.0; // プールCへ還元された歪み手数料

  final List<double> distortionHistoryA = [];

  final List<double> distortionHistoryB = [];


  SimulationEngine({
    required this.poolA,
    required this.poolB,
    required this.poolC,
    this.baseFeeRate = 0.001,
    required this.feeType,
    this.feeMultiplier = 5.0,
  });

  /// 指定した方向における現在の歪値を計算
  /// isAtoB == true  : Aから見たBの歪値 ((M_B/A - ratioB/A) / M_B/A)
  /// isAtoB == false : Bから見たAの歪値 ((M_A/B - ratioA/B) / M_A/B)
  double calculateDistortion(StablecoinPool? In, StablecoinPool? Out , double rate_OutIn) {
    final resA = In!.reserve;
    final resB = Out!.reserve;

    if (resA == 0 || resB == 0) return 1.0;

    // A -> B の視点
    final ratio = resB / resA;
    return ((rate_OutIn - ratio) / rate_OutIn);
  }

  /// 手数料関数: 歪値の増分 (diff) から追加の歪み手数料率 (skewFeeRate) を算出
  double calculateSkewFeeRate(double before , double after) {

    if(after.abs() - before.abs() < 0  && before * after < 0) return 0;

    double after_abs = after.abs();
    switch (feeType) {
      case FeeFunctionType.linear:
        return after_abs  * feeMultiplier;
      case FeeFunctionType.quadratic:
        return pow(after_abs, 2) * feeMultiplier; // 2次曲線で急勾配化
      case FeeFunctionType.exponential:
        return (exp(after_abs) - 1) * feeMultiplier;
    }
  }

  /// スワップの1ステップ実行
  void stepSwap({required StablecoinPool pool1, required StablecoinPool pool2 ,required bool isAtoB, required double amountIn}) {
    final tokenIn = isAtoB ? pool1 : pool2;
    final tokenOut = isAtoB ? pool2 : pool1;
    final rate = rate_IN_OUT(tokenIn.rate, tokenOut.rate);

    // 1. 取引前の「その方向における」歪値
    final beforeDist = calculateDistortion(tokenIn,tokenOut, rate);

// 2. 取引後の予測リザーブに基づく歪値計算
    StablecoinPool nextIn = tokenIn;
    StablecoinPool nextOut = tokenOut;
    nextIn.reserve = tokenIn.reserve + amountIn;
    final estimatedGrossOut = amountIn * rate;
    final nextreserve = max(0.0, tokenOut.reserve - estimatedGrossOut);
    nextOut.reserve = nextreserve;

    // 取引後の「その方向における」歪値
    final afterDist = calculateDistortion(
      nextIn, nextOut , rate
    );
    //print("beforeDist : ${nextIn.symbol} : ${beforeDist}");
    //print("afterDist : ${nextIn.symbol} : ${afterDist}");

    var diff = afterDist - beforeDist;

    //print("diff : ${diff}");

    final skewFeeRate = calculateSkewFeeRate(beforeDist, afterDist);

    //print("rate : ${skewFeeRate} ${tokenIn.symbol}");

    // 金額の確定
    final grossOut = amountIn * rate;
    final baseFeeAmount = amountIn * baseFeeRate;
    final skewFeeAmount = amountIn * skewFeeRate;

    //print("swap : ${amountIn} ${tokenIn.symbol}");
    //print("skew : ${skewFeeAmount} ${tokenIn.symbol}");

    // プールと累積手数料の更新
    tokenIn.reserve += (amountIn * (1 + skewFeeRate));
    tokenOut.reserve -= grossOut;

    if (isAtoB) {
      totalBaseFeeInA += baseFeeAmount;
      totalSkewFeeInA += skewFeeAmount;
      distortionHistoryA.add(afterDist);
    } else {
      totalBaseFeeInB += baseFeeAmount;
      totalSkewFeeInB += skewFeeAmount;
      distortionHistoryB.add(afterDist);
    }
  }

  /// ランダムなユーザー取引を N 回シミュレート
  void runRandomSimulation2d({required StablecoinPool PoolA, required StablecoinPool PoolB, required int steps, required double maxTradeSizeA}) {

    for (int i = 0; i < steps; i++) {


      final rand = Random(); // 再現性のためのシード固定
      // 50%の確率で A->B または B->A
      final isAtoB = rand.nextBool();

      double amountIn;
      if (isAtoB) {
        // A -> B のスワップ（入力は Aトークン単位: 例 1 ~ 201 USDC）
        amountIn = rand.nextDouble() * maxTradeSizeA * rate_USDC_pol_0 + 1.0;
      } else {
        // B -> A のスワップ（入力は Bトークン単位: 例 163 ~ 32,763 JPYC）
        // A側のスケール(maxTradeSizeA)に真のレート M_B/A を掛けて B側のスケールに変換
        amountIn = rand.nextDouble() * maxTradeSizeA * rate_JPYC_pol_0  + 1.0;
      }

      stepSwap(pool1: PoolA, pool2: PoolB, isAtoB: isAtoB, amountIn: amountIn);
    }
  }

  /// ランダムなユーザー取引を N 回シミュレート
  void runRandomSimulation3d({required StablecoinPool PoolA, required StablecoinPool PoolB,required StablecoinPool PoolC, required int steps, required double maxTradeSizeA}) {
    print("0,${PoolA.reserve.toStringAsFixed(2)},${PoolB.reserve.toStringAsFixed(2)},${PoolC.reserve.toStringAsFixed(2)}");
    for (int i = 0; i < steps; i++) {
      final rand = Random(); // 再現性のためのシード固定
      // 50%の確率で A->B または B->A
      final isAtoB = rand.nextBool();

      final tradepair = rand.nextInt(2);

      late StablecoinPool pool1, pool2;
      switch(tradepair){
        //USDC - JPYC
        case 0:
          pool1 = poolA;
          pool2 = poolB;
          break;
        //JPYC - EURC
        case 1:
          pool1 = poolB;
          pool2 = poolC;
          break;
        //USDC - EURC
        case 2:
          pool1 = poolA;
          pool2 = poolC;
          break;
      }

      double amountIn;
      if (isAtoB) {
        // A -> B のスワップ（入力は Aトークン単位: 例 1 ~ 201 USDC）
        amountIn = rand.nextDouble() * maxTradeSizeA * pool1.rate + 1.0;
      } else {
        // B -> A のスワップ（入力は Bトークン単位: 例 163 ~ 32,763 JPYC）
        // A側のスケール(maxTradeSizeA)に真のレート M_B/A を掛けて B側のスケールに変換
        amountIn = rand.nextDouble() * maxTradeSizeA * pool2.rate  + 1.0;
      }

      stepSwap(pool1: pool1, pool2: pool2, isAtoB: isAtoB, amountIn: amountIn);

      print("${i+1},${PoolA.reserve.toStringAsFixed(2)},${PoolB.reserve.toStringAsFixed(2)},${PoolC.reserve.toStringAsFixed(2)}");
    }
  }


  void worstsim(){

    double amountIn = 2500;

    final tokenIn = poolA;
    final tokenOut = poolB;
    final rate = rate_JPYC_pol_0 / rate_USDC_pol_0 * 1.03;



    // 1. 取引前の「その方向における」歪値
    final beforeDist = calculateDistortion(tokenIn,tokenOut, rate);

// 2. 取引後の予測リザーブに基づく歪値計算
    StablecoinPool nextIn = tokenIn;
    StablecoinPool nextOut = tokenOut;
    nextIn.reserve = tokenIn.reserve + amountIn;
    final estimatedGrossOut = amountIn * rate;
    final nextreserve = max(0.0, tokenOut.reserve - estimatedGrossOut);
    nextOut.reserve = nextreserve;

    // 取引後の「その方向における」歪値
    final afterDist = calculateDistortion(
        nextIn, nextOut , rate
    );
    print("beforeDist : ${nextIn.symbol} : ${beforeDist}");
    print("afterDist : ${nextIn.symbol} : ${afterDist}");

    var diff = afterDist - beforeDist;

    final skewFeeRate = calculateSkewFeeRate(beforeDist, afterDist);

    print("rate : ${skewFeeRate} ");

    // 金額の確定
    final grossOut = amountIn * rate;
    final baseFeeAmount = amountIn * baseFeeRate;
    final skewFeeAmount = amountIn * skewFeeRate;

    print("swap : ${amountIn} ${tokenIn.symbol}");
    print("skew : ${skewFeeAmount} ${tokenIn.symbol}");


  }

  void watchhistory(){
    print("History A:");
    for (var data in distortionHistoryA.asMap().entries){
      print('${data.value}');
    }
    print("History B:");
    for (var data in distortionHistoryB.asMap().entries){
      print('${data.value}');
    }
  }

}
