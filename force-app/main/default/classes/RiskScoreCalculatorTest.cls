@IsTest
private class RiskScoreCalculatorTest {
    @IsTest
    static void scoresTypicalLoan() {
        // 20 000 / 2 500 = 8  +  (48 - 12) * 30 / 84 = 12,86  +  5 * 3 = 15  ->  35,86 -> 36
        Assert.areEqual(36, RiskScoreCalculator.score(20000, 5, 48));
    }

    @IsTest
    static void capsEachComponent() {
        Assert.areEqual(100, RiskScoreCalculator.score(500000, 25, 96), 'Chaque composante est plafonnée');
    }

    @IsTest
    static void lowRiskLoan() {
        Assert.areEqual(1, RiskScoreCalculator.score(2500, 0, 12), 'Petit montant, durée minimale, taux nul');
    }

    @IsTest
    static void returnsNullWhenInputMissing() {
        Assert.isNull(RiskScoreCalculator.score(null, 5, 48));
        Assert.isNull(RiskScoreCalculator.score(20000, null, 48));
        Assert.isNull(RiskScoreCalculator.score(20000, 5, null));
    }
}
