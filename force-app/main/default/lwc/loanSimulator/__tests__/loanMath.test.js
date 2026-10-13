import { monthlyPayment, totalInterest } from "../loanMath";

describe("loanMath", () => {
  // Mêmes cas que LoanCalculatorTest (Apex) : l'aperçu JS doit donner la même mensualité que le serveur
  it.each([
    [20000, 5, 48, 460.59],
    [25000, 4.5, 60, 466.08],
    [35000, 3.9, 84, 476.8],
    [10000, 9.9, 12, 878.69]
  ])(
    "monthlyPayment(%p, %p %%, %p mois) = %p",
    (amount, rate, term, expected) => {
      expect(monthlyPayment(amount, rate, term)).toBe(expected);
    }
  );

  it("divise simplement le montant quand le taux est nul", () => {
    expect(monthlyPayment(12000, 0, 36)).toBe(333.33);
  });

  it("renvoie null si une donnée manque ou si la durée est invalide", () => {
    expect(monthlyPayment(null, 5, 48)).toBeNull();
    expect(monthlyPayment(20000, null, 48)).toBeNull();
    expect(monthlyPayment(20000, 5, 0)).toBeNull();
  });

  it("calcule le coût total des intérêts", () => {
    expect(totalInterest(20000, 460.59, 48)).toBe(2108.32);
    expect(totalInterest(null, 460.59, 48)).toBeNull();
  });
});
