import abilityTest from './Ability.test';
import createTest from './Create.test';
import settleTest from './Settle.test';
import regressionTest from './Regression.test';

export default function testsuite() {
  abilityTest();
  createTest();
  settleTest();
  regressionTest();
}
