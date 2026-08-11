import 'dart:math';
import 'calc.dart';

void main() {
  print('=== Distortion Value Convergence & Fee Verification ===\n');

  // 実験設定: 1 pol = 12 JPY = 0.076 USD
  // 初期リザーブ: 各100,000 pol

  // テストする手数料関数のタイプ
  final functionsToTest = [
    //FeeFunctionType.linear,
    FeeFunctionType.quadratic,
    //FeeFunctionType.exponential
  ];
  //twoassetsim(functionsToTest[0]);
  threeassetsim(functionsToTest[0]);
}

void threeassetsim(FeeFunctionType Func){
  final poolA = StablecoinPool(symbol: 'USDC', reserve: 10000,  fees: 0, rate: rate_USDC_USDC_0);
  final poolB = StablecoinPool(symbol: 'JPYC', reserve: 1592200, fees: 0, rate: rate_JPYC_USDC_0);
  final poolC = StablecoinPool(symbol: 'EURC', reserve: 8700, fees: 0, rate: rate_EURC_USDC_0);

  final engine = SimulationEngine(
    poolA: poolA,
    poolB: poolB,
    poolC: poolC,
    feeType: Func,
  );

  engine.runRandomSimulation3d(PoolA : poolA, PoolB : poolB,PoolC: poolC, steps: 1000, maxTradeSizeA: 100);
}

void twoassetsim(FeeFunctionType Func){
  final poolA = StablecoinPool(symbol: 'USDC', reserve: 7600,  fees: 0, rate: rate_USDC_pol_0);
  final poolB = StablecoinPool(symbol: 'JPYC', reserve: 1200000, fees: 0, rate: rate_JPYC_pol_0);
  final poolC = StablecoinPool(symbol: 'EURC', reserve: 6600, fees: 0, rate: rate_EURC_pol_0);

  final engine = SimulationEngine(
    poolA: poolA,
    poolB: poolB,
    poolC: poolC,
    feeType: Func,
  );

  //engine.worstsim();
  //engine.worstsim();
  // 500回のランダムスワップ取引を実行
  engine.runRandomSimulation2d(PoolA : poolA, PoolB : poolB, steps: 2000, maxTradeSizeA: 1000);

  final history = engine.distortionHistoryA;
  final avgDistortion = history.reduce((a, b) => a + b) / history.length;
  final maxDistortion = history.reduce(max);
  final minDistortion = history.reduce(min);
  final finalDistortion = history.last;
  final historyB = engine.distortionHistoryB;
  final avgDistortionB = historyB.reduce((a, b) => a + b) / history.length;
  final maxDistortionB = historyB.reduce(max);
  final minDistortionB = historyB.reduce(min);
  final finalDistortionB = historyB.last;

  print('>>> Fee Function Type: ${Func.name.toUpperCase()} <<<');
  print('Distortion Stats over 500 Trades:');
  print('  - Max Distortion USDC  : ${(maxDistortion * 100).toStringAsFixed(2)}%');
  print('  - Min Distortion USDC  : ${(minDistortion * 100).toStringAsFixed(2)}%');
  print('  - Final Distortion USDC : ${(finalDistortion * 100).toStringAsFixed(2)}%');
  print('  - Average Distortion USDC : ${(avgDistortion * 100).toStringAsFixed(2)}%');
  print('  - Max Distortion JPYC  : ${(maxDistortionB * 100).toStringAsFixed(2)}%');
  print('  - Min Distortion JPYC  : ${(minDistortionB * 100).toStringAsFixed(2)}%');
  print('  - Final Distortion JPYC : ${(finalDistortionB * 100).toStringAsFixed(2)}%');
  print('  - Average Distortion JPYC : ${(avgDistortionB * 100).toStringAsFixed(2)}%');
  engine.watchhistory();
  print('Accumulated Fees:');
  print('  - LP Holder Fees   : ${engine.totalBaseFeeInA.toStringAsFixed(2)} USDC | ${engine.totalBaseFeeInB.toStringAsFixed(2)} JPYC');
  print('  - Pool Rebalance   : ${engine.totalSkewFeeInA.toStringAsFixed(2)} USDC | ${engine.totalSkewFeeInB.toStringAsFixed(2)} JPYC');
  print('Final Reserve State:');
  print('  - USDC Reserve     : ${poolA.reserve.toStringAsFixed(2)}');
  print('  - JPYC Reserve     : ${poolB.reserve.toStringAsFixed(2)}');
  print('---------------------------------------------------\n');

}