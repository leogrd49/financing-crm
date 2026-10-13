@IsTest
private class LoanCalculatorTest {
    @IsTest
    static void computesStandardLoan() {
        Assert.areEqual(460.59, LoanCalculator.monthlyPayment(20000, 5, 48), '20 000 € à 5 % sur 48 mois');
        Assert.areEqual(466.08, LoanCalculator.monthlyPayment(25000, 4.5, 60), '25 000 € à 4,5 % sur 60 mois');
        Assert.areEqual(476.80, LoanCalculator.monthlyPayment(35000, 3.9, 84), '35 000 € à 3,9 % sur 84 mois');
        Assert.areEqual(878.69, LoanCalculator.monthlyPayment(10000, 9.9, 12), '10 000 € à 9,9 % sur 12 mois');
    }

    @IsTest
    static void zeroRateSplitsAmountEvenly() {
        Assert.areEqual(333.33, LoanCalculator.monthlyPayment(12000, 0, 36), 'Taux 0 : P / n, arrondi au centime');
    }

    @IsTest
    static void roundsToTwoDecimals() {
        Decimal result = LoanCalculator.monthlyPayment(20000, 5, 48);
        Assert.areEqual(2, result.scale(), 'La mensualité doit être arrondie au centime');
    }

    @IsTest
    static void returnsNullWhenInputMissing() {
        Assert.isNull(LoanCalculator.monthlyPayment(null, 5, 48), 'Montant null');
        Assert.isNull(LoanCalculator.monthlyPayment(20000, null, 48), 'Taux null');
        Assert.isNull(LoanCalculator.monthlyPayment(20000, 5, null), 'Durée null');
    }

    @IsTest
    static void rejectsNonPositiveTerm() {
        try {
            LoanCalculator.monthlyPayment(20000, 5, 0);
            Assert.fail('Une durée de 0 mois doit lever une IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            Assert.isNotNull(e.getMessage(), 'L\'exception doit avoir un message');
        }
    }
}
