import { createElement } from "@lwc/engine-dom";
import LoanSimulator from "c/loanSimulator";
import { getRecord, notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import applyTerms from "@salesforce/apex/LoanSimulatorController.applyTerms";

jest.mock(
  "@salesforce/apex/LoanSimulatorController.applyTerms",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "lightning/uiRecordApi",
  () => {
    const {
      createLdsTestWireAdapter
    } = require("@salesforce/wire-service-jest-util");
    const fieldName = (field) =>
      (typeof field === "string" ? field : field.fieldApiName).split(".").pop();
    return {
      getRecord: createLdsTestWireAdapter(jest.fn()),
      getFieldValue: (record, field) =>
        record?.fields?.[fieldName(field)]?.value,
      notifyRecordUpdateAvailable: jest.fn(() => Promise.resolve())
    };
  },
  { virtual: true }
);

const record = (status = "Draft") => ({
  id: "a00000000000001AAA",
  fields: {
    Amount__c: { value: 20000 },
    Term_Months__c: { value: 48 },
    Interest_Rate__c: { value: 5 },
    Monthly_Payment__c: { value: 460.59 },
    Status__c: { value: status }
  }
});

// Laisse le rendu et les promesses en attente se terminer (pattern des LWC Recipes)
// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
  const element = createElement("c-loan-simulator", { is: LoanSimulator });
  element.recordId = "a00000000000001AAA";
  document.body.appendChild(element);
  return element;
}

const query = (element, id) =>
  element.shadowRoot.querySelector(`[data-id="${id}"]`);
const simulated = (element) =>
  query(element, "simulated").querySelector("lightning-formatted-number").value;

describe("c-loan-simulator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("affiche la mensualité du dossier", async () => {
    const element = mount();
    getRecord.emit(record());
    await flushPromises();

    expect(simulated(element)).toBe(460.59);
    expect(query(element, "apply").disabled).toBe(true);
  });

  it("recalcule en direct quand la durée change", async () => {
    const element = mount();
    getRecord.emit(record());
    await flushPromises();

    const slider = query(element, "term");
    slider.value = 60;
    slider.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    expect(simulated(element)).toBe(377.42);
    expect(query(element, "apply").disabled).toBe(false);
  });

  it("recalcule en direct quand le taux change", async () => {
    const element = mount();
    getRecord.emit(record());
    await flushPromises();

    const rate = query(element, "rate");
    rate.value = "0";
    rate.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    expect(simulated(element)).toBe(416.67);
  });

  it("applique les conditions puis rafraîchit la fiche", async () => {
    applyTerms.mockResolvedValue({
      Id: "a00000000000001AAA",
      Monthly_Payment__c: 377.42
    });
    const element = mount();
    getRecord.emit(record());
    await flushPromises();

    const slider = query(element, "term");
    slider.value = 60;
    slider.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    query(element, "apply").click();
    await flushPromises();

    expect(applyTerms).toHaveBeenCalledWith({
      applicationId: "a00000000000001AAA",
      termMonths: 60,
      interestRate: 5
    });
    expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([
      { recordId: "a00000000000001AAA" }
    ]);
  });

  it("affiche une erreur si Salesforce refuse", async () => {
    applyTerms.mockRejectedValue({
      body: { message: "La durée doit être entre 12 et 96 mois." }
    });
    const element = mount();
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    getRecord.emit(record());
    await flushPromises();

    const slider = query(element, "term");
    slider.value = 60;
    slider.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    query(element, "apply").click();
    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.variant).toBe("error");
    expect(notifyRecordUpdateAvailable).not.toHaveBeenCalled();
  });

  it("passe en lecture seule pour un dossier non brouillon", async () => {
    const element = mount();
    getRecord.emit(record("Submitted"));
    await flushPromises();

    expect(query(element, "apply")).toBeNull();
    expect(query(element, "locked")).not.toBeNull();
  });
});
