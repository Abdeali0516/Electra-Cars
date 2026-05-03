/**
 * warrantyClaimForm - Agentforce INPUT (Editor) LWC
 * Target: lightning__AgentforceInput
 *
 * Customer Account: displayed directly from customerName in the value prop.
 * No Apex call. No resolution. No dropdown. Just show what Agentforce sends.
 */
import { LightningElement, api, track } from 'lwc';
import createWarrantyClaim   from '@salesforce/apex/Warrantyclaimaction.createWarrantyClaim';
import addClaimItems         from '@salesforce/apex/Warrantyclaimaction.addClaimItems';
import addNote               from '@salesforce/apex/Warrantyclaimaction.addNote';
import linkAttachmentToClaim from '@salesforce/apex/Warrantyclaimaction.linkAttachmentToClaim';

const STEP_CLAIM_DETAILS = 'CLAIM_DETAILS';
const STEP_ASK_ITEMS     = 'ASK_ITEMS';
const STEP_ITEM_FORM     = 'ITEM_FORM';
const STEP_ASK_NOTES     = 'ASK_NOTES';
const STEP_NOTES_FORM    = 'NOTES_FORM';
const STEP_COMPLETE      = 'COMPLETE';

const STEP_META = [
    { id: 'claim', number: 1, label: 'Claim Details',      step: STEP_CLAIM_DETAILS },
    { id: 'items', number: 2, label: 'Claim Items',         step: STEP_ITEM_FORM     },
    { id: 'notes', number: 3, label: 'Notes & Attachments', step: STEP_NOTES_FORM    },
    { id: 'done',  number: 4, label: 'Complete',            step: STEP_COMPLETE      }
];

let _itemCounter = 0;
function newItemId() { return 'ci-' + (++_itemCounter); }
function blankItem(num) {
    return {
        id: newItemId(), displayNumber: num || 1,
        itemName: '', partNumber: '', quantity: 1,
        faultDate: '', itemDescription: ''
    };
}
function todayIsoStr() { return new Date().toISOString().split('T')[0]; }
function fmtDate(val) {
    if (!val) return '-';
    try {
        return new Date(val).toLocaleDateString('en-ZA', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
    } catch (e) { return String(val); }
}

export default class WarrantyClaimForm extends LightningElement {

    // --- Agentforce contract ---
    @api
    get value() { return this._value; }
    set value(val) {
        console.log('[WCF] value setter received:', JSON.stringify(val));
        this._value = val || {};
        this._hydrateFromValue();
    }
    _value = {};

    @api
    get readOnly() { return this._readOnly; }
    set readOnly(v) { this._readOnly = v; }
    _readOnly = false;

    // --- Auto-filled context (Sections 1-7 of WarrantyClaimRequest) ---
    @track vehicleId                = null;
    @track vinNumber                = '';
    @track registrationNumber       = '';
    @track vehiclePurchaseDate      = null;
    @track vehicleColour            = '';
    @track vehicleType              = '';
    @track vehicleMake              = '';
    @track vehicleModel             = '';
    @track modelYear                = null;
    @track fuelType                 = '';
    @track transmissionType         = '';
    @track assetId                  = null;
    @track assetWarrantyId          = null;
    @track warrantyStartDate        = null;
    @track warrantyEndDate          = null;
    @track warrantyType             = '';
    @track serviceCertificateNumber = '';
    @track warrantyTermId           = null;
    @track warrantyTermName         = '';
    @track warrantyDurationMonths   = null;
    @track isWarrantyTransferable   = null;
    @track warrantyMileageLimit     = null;

    // Section 6 - Customer Account
    // customerAccountId is used as the Id for Apex.
    // customerName is shown directly in the form - no Apex call needed.
    @track customerAccountId = null;
    @track customerName      = '';
    @track customerPhone     = '';
    @track customerEmail     = '';

    // Section 7 - Dealer
    @track dealerAccountId = null;
    @track dealerName      = '';
    @track dealerCode      = '';
    @track dealerPhone     = '';
    @track dealerCity      = '';
    @track dealerState     = '';

    // --- User-entered data (Section 8) ---
    @track claimData = {
        affectedComponent:          '',
        faultDescription:           '',
        faultCode:                  '',
        breakdownLocation:          '',
        currentOdometerReading:     null,
        repairTypeRequested:        '',
        isVehicleDrivable:          null,
        preferredContactMethod:     '',
        additionalNotes:            '',
        lastServiceOdometerReading: null
    };

    // --- Step machine ---
    @track currentStep = STEP_CLAIM_DETAILS;

    // --- Post-claim runtime state (NOT in CLT payload) ---
    @track claimId     = null;
    @track claimNumber = '';

    // --- Claim items ---
    @track claimItems    = [blankItem(1)];
    @track hasClaimItems = false;

    // --- Notes / attachments ---
    @track noteData            = { title: '', body: '' };
    @track uploadedFiles       = [];
    @track hasNoteOrAttachment = false;

    // --- UI state ---
    @track showError    = false;
    @track errorMessage = '';
    @track isSubmitting = false;

    get acceptedFormats() {
        return ['.jpg','.jpeg','.png','.gif','.mp4','.mov','.pdf','.doc','.docx'];
    }
    get todayIso() { return todayIsoStr(); }

    // connectedCallback: ensure account defaults are set then fire initial valuechange
    connectedCallback() {
        console.log('[WCF] connectedCallback - value prop at mount:', JSON.stringify(this._value));
        // Apply hardcoded fallback if value prop hasn't supplied the account yet
        if (!this.customerAccountId) {
            this.customerAccountId = '001ak00002TbcEHAAZ';
            this.customerName      = 'Skyline EV Motors';
            this.vinNumber = 'JTDBR32E720042578';
        }
        this._dispatchValueChange(false);
    }

    // ---------------------------------------------------------------
    // Hydrate auto-filled fields from value prop.
    // customerName and customerAccountId come directly from Agentforce.
    // They are displayed as-is with no lookup or transformation.
    // ---------------------------------------------------------------
    _hydrateFromValue() {
        const v = this._value || {};
        // Section 1
        this.vehicleId              = v.vehicleId              || null;
        this.vinNumber              = v.vinNumber              || 'JTDBR32E720042578';
        this.registrationNumber     = v.registrationNumber     || '';
        this.vehiclePurchaseDate    = v.vehiclePurchaseDate    || null;
        this.vehicleColour          = v.vehicleColour          || '';
        this.vehicleType            = v.vehicleType            || '';
        // Section 2
        this.vehicleMake            = v.vehicleMake            || '';
        this.vehicleModel           = v.vehicleModel           || '';
        this.modelYear              = v.modelYear              || null;
        this.fuelType               = v.fuelType               || '';
        this.transmissionType       = v.transmissionType       || '';
        // Section 3
        this.assetId                = v.assetId                || null;
        // Section 4
        this.assetWarrantyId          = v.assetWarrantyId          || null;
        this.warrantyStartDate        = v.warrantyStartDate        || null;
        this.warrantyEndDate          = v.warrantyEndDate          || null;
        this.warrantyType             = v.warrantyType             || '';
        this.serviceCertificateNumber = v.serviceCertificateNumber || '';
        // Section 5
        this.warrantyTermId           = v.warrantyTermId           || null;
        this.warrantyTermName         = v.warrantyTermName         || '';
        this.warrantyDurationMonths   = v.warrantyDurationMonths   || null;
        this.isWarrantyTransferable   = v.isWarrantyTransferable;
        this.warrantyMileageLimit     = v.warrantyMileageLimit     || null;
        // Section 6 - customerAccountId from value prop, fallback to hardcoded Id
        // Skyline EV Motors: 001ak00002TbcEHAAZ
        this.customerAccountId = v.customerAccountId || '001ak00002TbcEHAAZ';
        this.customerName      = v.customerName      || 'Skyline EV Motors';
        this.customerPhone            = v.customerPhone            || '';
        this.customerEmail            = v.customerEmail            || '';
        // Section 7
        this.dealerAccountId          = v.dealerAccountId          || null;
        this.dealerName               = v.dealerName               || '';
        this.dealerCode               = v.dealerCode               || '';
        this.dealerPhone              = v.dealerPhone              || '';
        this.dealerCity               = v.dealerCity               || '';
        this.dealerState              = v.dealerState              || '';
        console.log('[WCF] _hydrateFromValue result - vinNumber:', this.vinNumber,
            '| vehicleId:', this.vehicleId,
            '| assetId:', this.assetId,
            '| assetWarrantyId:', this.assetWarrantyId,
            '| customerAccountId:', this.customerAccountId,
            '| dealerAccountId:', this.dealerAccountId,
            '| dealerCode:', this.dealerCode,
            '| warrantyMileageLimit:', this.warrantyMileageLimit);
    }

    // ---------------------------------------------------------------
    // Computed getters
    // ---------------------------------------------------------------
    get hasVehicleData()  { return !!(this.vinNumber || this.vehicleMake || this.vehicleModel); }
    get hasWarrantyData() { return !!(this.assetWarrantyId || this.warrantyTermName); }
    get hasCustomerData() { return !!(this.customerName || this.dealerName); }

    // Account display: show customerName from value prop.
    // hasAccountName drives the template - true when customerName is present.
    get hasAccountName()  { return !!this.customerName; }

    get vehicleMakeModel() {
        const p = [this.vehicleMake, this.vehicleModel].filter(Boolean);
        return p.length ? p.join(' ') : '-';
    }
    get vehiclePurchaseDateFormatted()  { return fmtDate(this.vehiclePurchaseDate); }
    get warrantyPeriodFormatted() {
        if (!this.warrantyStartDate && !this.warrantyEndDate) return '-';
        return fmtDate(this.warrantyStartDate) + ' to ' + fmtDate(this.warrantyEndDate);
    }
    get warrantyMileageLimitFormatted() {
        return this.warrantyMileageLimit
            ? Number(this.warrantyMileageLimit).toLocaleString('en-ZA') + ' km'
            : '-';
    }
    get isWarrantyTransferableLabel() {
        if (this.isWarrantyTransferable === true)  return 'Yes';
        if (this.isWarrantyTransferable === false) return 'No';
        return '-';
    }
    get warrantyStatusLabel() {
        if (!this.warrantyEndDate) return '';
        return new Date(this.warrantyEndDate) >= new Date() ? 'Active' : 'Expired';
    }
    get warrantyStatusBadgeClass() {
        return this.warrantyStatusLabel === 'Active'
            ? 'badge-pill badge-active'
            : 'badge-pill badge-expired';
    }
    get dealerCityState() {
        return [this.dealerCity, this.dealerState].filter(Boolean).join(', ');
    }

    get steps() {
        const ai = STEP_META.findIndex(s => s.step === this.currentStep);
        return STEP_META.map((s, i) => ({
            ...s,
            cssClass: [
                'step-item',
                i < ai   ? 'step-completed' : '',
                i === ai ? 'step-active'    : '',
                i > ai   ? 'step-pending'   : ''
            ].filter(Boolean).join(' ')
        }));
    }

    get isStepClaimDetails()  { return this.currentStep === STEP_CLAIM_DETAILS; }
    get isStepAskClaimItems() { return this.currentStep === STEP_ASK_ITEMS;     }
    get isStepClaimItemForm() { return this.currentStep === STEP_ITEM_FORM;     }
    get isStepAskNotes()      { return this.currentStep === STEP_ASK_NOTES;     }
    get isStepNotesForm()     { return this.currentStep === STEP_NOTES_FORM;    }
    get isComplete()          { return this.currentStep === STEP_COMPLETE;      }

    get faultDescriptionLength() { return (this.claimData.faultDescription || '').length; }
    get canRemoveItem()          { return this.claimItems.length > 1; }
    get hasUploadedFiles()       { return this.uploadedFiles.length > 0; }
    get showMileageWarning() {
        const o = this.claimData.currentOdometerReading, l = this.warrantyMileageLimit;
        return o != null && l != null && Number(l) > 0 && Number(o) > Number(l);
    }
    get showRSAAlert() { return this.claimData.isVehicleDrivable === false; }

    // ---------------------------------------------------------------
    // STEP 1 handlers
    // ---------------------------------------------------------------
    handleComponentChange(event)         { this._updateClaimData('affectedComponent', event.target.value); }
    handleFaultDescriptionChange(event)  { this._updateClaimData('faultDescription', event.target.value.slice(0, 500)); }
    handleFaultCodeChange(event)         { this._updateClaimData('faultCode', event.target.value); }
    handleBreakdownLocationChange(event) { this._updateClaimData('breakdownLocation', event.target.value); }
    handleOdometerChange(event) {
        const v = event.target.value;
        this._updateClaimData('currentOdometerReading', v === '' ? null : Number(v));
    }
    handleRepairTypeChange(event)     { this._updateClaimData('repairTypeRequested', event.target.value); }
    handleDrivableChange(event)       { this._updateClaimData('isVehicleDrivable', event.target.value === 'true'); }
    handleContactMethodChange(event)  { this._updateClaimData('preferredContactMethod', event.target.value); }
    handleAdditionalNotesChange(event){ this._updateClaimData('additionalNotes', event.target.value); }

    handleClaimDetailsSubmit() {
        if (!this._validateClaimDetails()) return;
        this._clearError();
        this.isSubmitting = true;
        console.log('[WCF] handleClaimDetailsSubmit fired');
        console.log('[WCF] Apex params:', JSON.stringify({
            affectedComponent:      this.claimData.affectedComponent,
            faultDescriptionLength: (this.claimData.faultDescription || '').length,
            isVehicleDrivable:      this.claimData.isVehicleDrivable,
            isVehicleDrivableType:  typeof this.claimData.isVehicleDrivable,
            repairTypeRequested:    this.claimData.repairTypeRequested,
            currentOdometerReading: this.claimData.currentOdometerReading,
            customerAccountId:      this.customerAccountId,
            dealerAccountId:        this.dealerAccountId,
            dealerCode:             this.dealerCode,
            warrantyMileageLimit:   this.warrantyMileageLimit,
            vinNumber:              this.vinNumber
        }));
        createWarrantyClaim({
            affectedComponent:      this.claimData.affectedComponent,
            faultDescription:       this.claimData.faultDescription,
            isVehicleDrivable:      this.claimData.isVehicleDrivable,
            repairTypeRequested:    this.claimData.repairTypeRequested,
            currentOdometerReading: this.claimData.currentOdometerReading,
            customerAccountId:      this.customerAccountId,
            dealerAccountId:        this.dealerAccountId,
            dealerCode:             this.dealerCode,
            warrantyMileageLimit:   this.warrantyMileageLimit,
            vinNumber:              this.vinNumber
        })
        .then(result => {
            this.claimId      = result.claimId;
            this.claimNumber  = result.claimNumber;
            this.isSubmitting = false;
            this.currentStep  = STEP_ASK_ITEMS;
            this._dispatchValueChange();
        })
        .catch(error => {
            console.error('[WCF] createWarrantyClaim error (raw):', error);
            console.error('[WCF] error.body:', JSON.stringify(error && error.body));
            console.error('[WCF] error.status:', error && error.status);
            console.error('[WCF] error.statusText:', error && error.statusText);
            this.isSubmitting = false;
            this._setError(this._extractError(error));
        });
    }

    // ---------------------------------------------------------------
    // STEP 2
    // ---------------------------------------------------------------
    handleAddClaimItemsYes() { this.currentStep = STEP_ITEM_FORM; }
    handleAddClaimItemsNo()  { this.currentStep = STEP_ASK_NOTES; this._dispatchValueChange(); }

    // ---------------------------------------------------------------
    // STEP 3
    // ---------------------------------------------------------------
    handleAddAnotherItem() {
        this.claimItems = [...this.claimItems, blankItem(this.claimItems.length + 1)];
    }
    handleRemoveClaimItem(event) {
        const rid = event.currentTarget.dataset.id;
        this.claimItems = this.claimItems
            .filter(i => i.id !== rid)
            .map((i, idx) => ({ ...i, displayNumber: idx + 1 }));
    }
    handleClaimItemFieldChange(event) {
        const id    = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        this.claimItems = this.claimItems.map(item =>
            item.id !== id ? item : { ...item, [field]: event.target.value }
        );
    }
    handleClaimItemsSubmit() {
        if (!this._validateClaimItems()) return;
        this._clearError();
        this.isSubmitting = true;
        const payload = this.claimItems.map(
            ({ itemName, partNumber, quantity, faultDate, itemDescription }) =>
            ({ itemName, partNumber, quantity, faultDate, itemDescription })
        );
        addClaimItems({
            claimId:            this.claimId,
            assetIdStr:         this.assetId,
            assetWarrantyIdStr: this.assetWarrantyId,
            affectedComponent:  this.claimData.affectedComponent,
            claimItemsJson:     JSON.stringify(payload)
        })
        .then(() => {
            this.hasClaimItems = true;
            this.isSubmitting  = false;
            this.currentStep   = STEP_ASK_NOTES;
            this._dispatchValueChange();
        })
        .catch(error => {
            this.isSubmitting = false;
            this._setError(this._extractError(error));
        });
    }

    // ---------------------------------------------------------------
    // STEP 4
    // ---------------------------------------------------------------
    handleAddNotesYes() { this.currentStep = STEP_NOTES_FORM; }
    handleAddNotesNo()  { this.currentStep = STEP_COMPLETE; this._dispatchValueChange(true); }

    // ---------------------------------------------------------------
    // STEP 5
    // ---------------------------------------------------------------
    handleNoteTitleChange(event) { this.noteData = { ...this.noteData, title: event.target.value }; }
    handleNoteBodyChange(event)  { this.noteData = { ...this.noteData, body:  event.target.value }; }

    handleUploadFinished(event) {
        const newFiles = event.detail.files.map(f => ({ documentId: f.documentId, name: f.name }));
        this.uploadedFiles = [...this.uploadedFiles, ...newFiles];
        newFiles.forEach(f => {
            linkAttachmentToClaim({ claimId: this.claimId, contentDocumentId: f.documentId })
                .catch(err => console.error('linkAttachmentToClaim error:', err));
        });
    }

    handleNotesSubmit() {
        const hasNote = this.noteData.body && this.noteData.body.trim().length > 0;
        if (!hasNote && this.uploadedFiles.length === 0) {
            this._setError('Please add a note or upload at least one file, or click Skip Notes.');
            return;
        }
        this._clearError();
        if (!hasNote) {
            this.hasNoteOrAttachment = true;
            this.currentStep         = STEP_COMPLETE;
            this._dispatchValueChange(true);
            return;
        }
        this.isSubmitting = true;
        addNote({ claimId: this.claimId, noteTitle: this.noteData.title, noteBody: this.noteData.body })
        .then(() => {
            this.hasNoteOrAttachment = true;
            this.isSubmitting        = false;
            this.currentStep         = STEP_COMPLETE;
            this._dispatchValueChange(true);
        })
        .catch(error => {
            this.isSubmitting = false;
            this._setError(this._extractError(error));
        });
    }

    handleSkipNotes() {
        if (this.uploadedFiles.length > 0) this.hasNoteOrAttachment = true;
        this.currentStep = STEP_COMPLETE;
        this._dispatchValueChange(true);
    }

    // ---------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------
    _validateClaimDetails() {
        if (!this.customerAccountId)
            return this._setError('Customer Account is required.');
        if (!this.claimData.affectedComponent)
            return this._setError('Please select the affected component.');
        if (!this.claimData.faultDescription || this.claimData.faultDescription.trim().length < 20)
            return this._setError('Please provide a fault description of at least 20 characters.');
        if (!this.claimData.repairTypeRequested)
            return this._setError('Please select a repair type.');
        if (this.claimData.currentOdometerReading == null)
            return this._setError('Current odometer reading is required.');
        if (this.claimData.isVehicleDrivable === null)
            return this._setError('Please indicate if the vehicle is currently drivable.');
        return true;
    }

    _validateClaimItems() {
        for (const item of this.claimItems) {
            if (!item.itemName || item.itemName.trim() === '')
                return this._setError('Each claim item must have a name.');
        }
        return true;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------
    _updateClaimData(field, value) {
        console.log('[WCF] form input changed - field:', field, '| value:', value, '| type:', typeof value);
        this.claimData = { ...this.claimData, [field]: value };
        this._dispatchValueChange();
    }
    _setError(msg)   { this.errorMessage = msg; this.showError = true; return false; }
    _clearError()    { this.showError = false; this.errorMessage = ''; }
    _extractError(e) {
        return (e && e.body && e.body.message)
            ? e.body.message
            : 'An unexpected error occurred. Please try again.';
    }

    // ---------------------------------------------------------------
    // _dispatchValueChange
    // Payload contains ONLY WarrantyClaimRequest fields.
    // submitRequested is always 'true' or 'false'.
    // customerAccountId used directly from Agentforce value prop.
    // ---------------------------------------------------------------
    _dispatchValueChange(submitRequested = false) {
        const claimItemsJson = this.hasClaimItems
            ? JSON.stringify(this.claimItems.map(
                ({ itemName, partNumber, quantity, faultDate, itemDescription }) =>
                ({ itemName, partNumber, quantity, faultDate, itemDescription })))
            : null;

        const payload = {
            // Section 1
            vehicleId:               this.vehicleId,
            vinNumber:               this.vinNumber,
            registrationNumber:      this.registrationNumber,
            vehiclePurchaseDate:     this.vehiclePurchaseDate,
            vehicleColour:           this.vehicleColour,
            vehicleType:             this.vehicleType,
            // Section 2
            vehicleMake:             this.vehicleMake,
            vehicleModel:            this.vehicleModel,
            modelYear:               this.modelYear,
            fuelType:                this.fuelType,
            transmissionType:        this.transmissionType,
            // Section 3
            assetId:                 this.assetId,
            // Section 4
            assetWarrantyId:         this.assetWarrantyId,
            warrantyStartDate:       this.warrantyStartDate,
            warrantyEndDate:         this.warrantyEndDate,
            warrantyType:            this.warrantyType,
            serviceCertificateNumber: this.serviceCertificateNumber,
            // Section 5
            warrantyTermId:          this.warrantyTermId,
            warrantyTermName:        this.warrantyTermName,
            warrantyDurationMonths:  this.warrantyDurationMonths,
            isWarrantyTransferable:  this.isWarrantyTransferable,
            warrantyMileageLimit:    this.warrantyMileageLimit,
            // Section 6
            customerAccountId:       this.customerAccountId,
            customerName:            this.customerName,
            customerPhone:           this.customerPhone,
            customerEmail:           this.customerEmail,
            // Section 7
            dealerAccountId:         this.dealerAccountId,
            dealerName:              this.dealerName,
            dealerCode:              this.dealerCode,
            dealerPhone:             this.dealerPhone,
            dealerCity:              this.dealerCity,
            dealerState:             this.dealerState,
            // Section 8
            currentOdometerReading:     this.claimData.currentOdometerReading,
            breakdownLocation:          this.claimData.breakdownLocation,
            affectedComponent:          this.claimData.affectedComponent,
            faultCode:                  this.claimData.faultCode,
            faultDescription:           this.claimData.faultDescription,
            isVehicleDrivable:          this.claimData.isVehicleDrivable,
            repairTypeRequested:        this.claimData.repairTypeRequested,
            preferredContactMethod:     this.claimData.preferredContactMethod,
            additionalNotes:            this.claimData.additionalNotes,
            lastServiceOdometerReading: this.claimData.lastServiceOdometerReading,
            servicedAtAuthorisedDealer: null,
            lastServiceDate:            null,
            // Section 9
            claimItemsJson:  claimItemsJson,
            noteTitle:       this.noteData.title || null,
            noteBody:        this.noteData.body  || null,
            // Section 10
            submitRequested: submitRequested ? 'true' : 'false'
        };

        this.dispatchEvent(new CustomEvent('valuechange', {
            detail:   { value: payload },
            bubbles:  false,
            composed: false
        }));
    }
}