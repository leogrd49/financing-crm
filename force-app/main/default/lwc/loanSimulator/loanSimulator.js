import { LightningElement, api, wire } from "lwc";
import {
  getRecord,
  getFieldValue,
  notifyRecordUpdateAvailable
} from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import applyTerms from "@salesforce/apex/LoanSimulatorController.applyTerms";
import AMOUNT_FIELD from "@salesforce/schema/Financing_Application__c.Amount__c";
import TERM_FIELD from "@salesforce/schema/Financing_Application__c.Term_Months__c";
import RATE_FIELD from "@salesforce/schema/Financing_Application__c.Interest_Rate__c";
import PAYMENT_FIELD from "@salesforce/schema/Financing_Application__c.Monthly_Payment__c";
import STATUS_FIELD from "@salesforce/schema/Financing_Application__c.Status__c";
import { monthlyPayment, totalInterest } from "./loanMath";

const FIELDS = [
  AMOUNT_FIELD,
  TERM_FIELD,
  RATE_FIELD,
  PAYMENT_FIELD,
  STATUS_FIELD
];
const STATUS_DRAFT = "Draft";

export default class LoanSimulator extends LightningElement {
  @api recordId;

  record;
  error;
  termMonths;
  interestRate;
  isSaving = false;

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredRecord({ data, error }) {
    if (data) {
      this.record = data;
      this.error = undefined;
      // Après un enregistrement, on repart des valeurs du serveur
      this.termMonths = getFieldValue(data, TERM_FIELD);
      this.interestRate = getFieldValue(data, RATE_FIELD);
    } else if (error) {
      this.error = error;
      this.record = undefined;
    }
  }

  get amount() {
    return getFieldValue(this.record, AMOUNT_FIELD);
  }

  get currentPayment() {
    return getFieldValue(this.record, PAYMENT_FIELD);
  }

  get simulatedPayment() {
    return monthlyPayment(this.amount, this.interestRate, this.termMonths);
  }

  get paymentDifference() {
    if (this.simulatedPayment == null || this.currentPayment == null) {
      return null;
    }
    return (
      Math.round((this.simulatedPayment - this.currentPayment) * 100) / 100
    );
  }

  get differenceClass() {
    const color =
      this.paymentDifference > 0
        ? "slds-text-color_error"
        : "slds-text-color_success";
    return `slds-item_detail ${color}`;
  }

  get simulatedTotalInterest() {
    return totalInterest(this.amount, this.simulatedPayment, this.termMonths);
  }

  get isDraft() {
    return getFieldValue(this.record, STATUS_FIELD) === STATUS_DRAFT;
  }

  get hasChanges() {
    return (
      this.termMonths !== getFieldValue(this.record, TERM_FIELD) ||
      this.interestRate !== getFieldValue(this.record, RATE_FIELD)
    );
  }

  get isApplyDisabled() {
    return !this.isDraft || !this.hasChanges || this.isSaving;
  }

  get errorMessage() {
    return this.error?.body?.message ?? "Impossible de charger le dossier.";
  }

  handleTermChange(event) {
    this.termMonths = Number(event.target.value);
  }

  handleRateChange(event) {
    const value = event.target.value;
    this.interestRate = value === "" || value == null ? null : Number(value);
  }

  handleReset() {
    this.termMonths = getFieldValue(this.record, TERM_FIELD);
    this.interestRate = getFieldValue(this.record, RATE_FIELD);
  }

  async handleApply() {
    this.isSaving = true;
    try {
      await applyTerms({
        applicationId: this.recordId,
        termMonths: this.termMonths,
        interestRate: this.interestRate
      });
      // Rafraîchit la fiche ET ce composant (le wire renvoie les nouvelles valeurs)
      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.toast(
        "success",
        "Conditions appliquées",
        "La mensualité a été recalculée par Salesforce."
      );
    } catch (error) {
      this.toast(
        "error",
        "Enregistrement impossible",
        error?.body?.message ?? "Erreur inconnue."
      );
    } finally {
      this.isSaving = false;
    }
  }

  toast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ variant, title, message }));
  }
}
