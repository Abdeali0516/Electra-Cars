import { LightningElement, api, wire, track } from 'lwc';
import getClaimRecord from '@salesforce/apex/ClaimListController.getClaimRecord';
import getClaimItems  from '@salesforce/apex/ClaimListController.getClaimItems';
import getClaimFiles  from '@salesforce/apex/ClaimListController.getClaimFiles';

// ── Formatters ────────────────────────────────────────────────────────────────

function fmt(val) {
    if (val === null || val === undefined || val === '') return '—';
    return String(val);
}

function fmtCurrency(val) {
    if (val == null || val === '') return '—';
    try {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(val);
    } catch (e) {
        return String(val);
    }
}

function fmtDate(val) {
    if (!val) return '—';
    return new Date(val).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function fmtBool(val) {
    if (val === null || val === undefined) return '—';
    return val ? 'Yes' : 'No';
}

function fmtFileSize(bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024)           return bytes + ' B';
    if (bytes < 1024 * 1024)    return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function fmtFileIcon(fileType) {
    if (!fileType) return 'doctype:unknown';
    const t = fileType.toUpperCase();
    if (t === 'PDF')  return 'doctype:pdf';
    if (t === 'SNOTE') return 'doctype:note';
    if (['PNG', 'JPG', 'JPEG', 'GIF', 'BMP', 'SVG', 'WEBP', 'HEIC'].includes(t)) return 'doctype:image';
    return 'doctype:unknown';
}

// ─────────────────────────────────────────────────────────────────────────────

export default class ClaimDetail extends LightningElement {

    // When used on a Lightning Record Page the platform sets recordId automatically.
    // When embedded inside claimList, claimId is passed instead.
    @track _activeId;

    @api
    get recordId() { return this._activeId; }
    set recordId(val) { this._activeId = val; }

    @api
    get claimId() { return this._activeId; }
    set claimId(val) { this._activeId = val; }

    @api showBackButton = false;

    // ── Record data ───────────────────────────────────────────────────────────
    @track _recordData  = null;
    @track _recordError = null;

    // ── ClaimItems ────────────────────────────────────────────────────────────
    @track _claimItems      = null;
    @track _claimItemsError = null;
    @track _selectedItemId  = null;

    // ── Files ─────────────────────────────────────────────────────────────────
    @track _claimFiles      = null;
    @track _claimFilesError = null;

    // ── Section expand state ──────────────────────────────────────────────────
    @track isInfoExpanded      = true;
    @track isAiSummaryExpanded = true;
    @track isItemsExpanded     = true;
    @track isFilesExpanded     = true;

    // ── Wires ─────────────────────────────────────────────────────────────────

    @wire(getClaimRecord, { claimId: '$_activeId' })
    wiredRecord({ data, error }) {
        if (data)       { this._recordData = data;  this._recordError = null; }
        else if (error) { this._recordError = error; this._recordData = null; }
    }

    @wire(getClaimItems, { claimId: '$_activeId' })
    wiredItems({ data, error }) {
        if (data)       { this._claimItems = data;      this._claimItemsError = null; }
        else if (error) { this._claimItemsError = error; this._claimItems = null; }
    }

    @wire(getClaimFiles, { claimId: '$_activeId' })
    wiredFiles({ data, error }) {
        if (data)       { this._claimFiles = data;       this._claimFilesError = null; }
        else if (error) { this._claimFilesError = error;  this._claimFiles = null; }
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    handleBack()     { this.dispatchEvent(new CustomEvent('back')); }
    handleViewItem(e){ this._selectedItemId = e.currentTarget.dataset.id; }
    handleItemBack() { this._selectedItemId = null; }

    // ── Record state ──────────────────────────────────────────────────────────

    get isLoading()    { return !this._recordData && !this._recordError && !!this._activeId; }
    get hasLoadError() { return !!this._recordError || !this._activeId; }
    get loadError() {
        if (!this._activeId) return 'No record Id provided.';
        return this._recordError?.body?.message || this._recordError?.message || 'Could not load claim record.';
    }
    get showContent() { return !!this._recordData; }

    get claimStatus() {
        return (this._recordData && this._recordData.Status) ? this._recordData.Status : null;
    }

    // ── Section toggles ───────────────────────────────────────────────────────

    toggleInfo()      { this.isInfoExpanded      = !this.isInfoExpanded;      }
    toggleAiSummary() { this.isAiSummaryExpanded = !this.isAiSummaryExpanded; }
    toggleItems()     { this.isItemsExpanded     = !this.isItemsExpanded;     }
    toggleFiles()     { this.isFilesExpanded     = !this.isFilesExpanded;     }

    get infoChevronClass()      { return 'chevron-wrap' + (this.isInfoExpanded      ? '' : ' chevron-collapsed'); }
    get aiSummaryChevronClass() { return 'chevron-wrap' + (this.isAiSummaryExpanded ? '' : ' chevron-collapsed'); }
    get itemsChevronClass()     { return 'chevron-wrap' + (this.isItemsExpanded     ? '' : ' chevron-collapsed'); }
    get filesChevronClass()     { return 'chevron-wrap' + (this.isFilesExpanded     ? '' : ' chevron-collapsed'); }

    // ── Highlight panel tiles ─────────────────────────────────────────────────

    get highlightTiles() {
        const d = this._recordData;
        if (!d) return [];
        const score = d.Confidence_Score__c;
        let scoreColorClass = 'hp-score-red';
        if (score >= 80)      scoreColorClass = 'hp-score-green';
        else if (score >= 50) scoreColorClass = 'hp-score-amber';

        return [
            {
                key:        'ConfidenceScore',
                label:      'Confidence Score',
                value:      score != null ? String(score) : '—',
                valueClass: 'hp-score-value ' + scoreColorClass,
            },
            {
                key:        'Account',
                label:      'Account',
                value:      fmt(d.Account ? d.Account.Name : d.AccountId),
                valueClass: 'hp-value',
            },
            {
                key:        'InsuredAsset',
                label:      'Insured Asset',
                value:      fmt(d.InsuredAsset ? d.InsuredAsset.Name : d.InsuredAssetId),
                valueClass: 'hp-value',
            },
            {
                key:        'EstimatedAmount',
                label:      'Estimated Amount',
                value:      fmtCurrency(d.EstimatedAmount),
                valueClass: 'hp-value',
            },
        ];
    }

    // ── Information card fields ───────────────────────────────────────────────

    get fieldsLeft() {
        const d = this._recordData;
        if (!d) return [];
        return [
            { key: 'Name',                label: 'Claim Number',               value: fmt(d.Name) },
            { key: 'AccountId',           label: 'Account',                    value: fmt(d.Account ? d.Account.Name : d.AccountId) },
            { key: 'ClaimType',           label: 'Claim Type',                 value: fmt(d.ClaimType) },
            { key: 'EstimatedAmount',     label: 'Estimated Amount',           value: fmtCurrency(d.EstimatedAmount) },
            { key: 'ActualAmount',        label: 'Actual Amount',              value: fmtCurrency(d.ActualAmount) },
            { key: 'ApprovedAmount',      label: 'Approved Amount',            value: fmtCurrency(d.ApprovedAmount) },
            { key: 'Severity',            label: 'Severity',                   value: fmt(d.Severity) },
            { key: 'FnolChannel',         label: 'FNOL Channel',               value: fmt(d.FnolChannel) },
            { key: 'IncidentSite',        label: 'Incident Site',              value: fmt(d.IncidentSite) },
            { key: 'TotalClaimedAmount',  label: 'Total Claimed Amount',       value: fmtCurrency(d.TotalClaimedAmount) },
            { key: 'FinancialAuthStatus', label: 'Financial Authority Status', value: fmt(d.FinancialAuthorityStatus) },
            { key: 'RelatedClaimId',      label: 'Related Claim',              value: fmt(d.RelatedClaimId) },
            { key: 'CurrencyIsoCode',     label: 'Currency',                   value: fmt(d.CurrencyIsoCode) },
            { key: 'ConfidenceScore',     label: 'Confidence Score',           value: fmt(d.Confidence_Score__c) },
            { key: 'AutoApproved',        label: 'Auto Approved',              value: fmtBool(d.Auto_Approved__c) },
            { key: 'FraudFlag',           label: 'Fraud Flag',                 value: fmtBool(d.Fruad_Flag__c) },
            { key: 'EvidenceCompleted',   label: 'Evidence Completed',         value: fmtBool(d.Evidence_Completed__c) },
        ];
    }

    get fieldsRight() {
        const d = this._recordData;
        if (!d) return [];
        return [
            { key: 'PolicyNumberId',      label: 'Policy Number',              value: fmt(d.PolicyNumberId) },
            { key: 'InsuredAssetId',      label: 'Insured Asset',              value: fmt(d.InsuredAsset ? d.InsuredAsset.Name : d.InsuredAssetId) },
            { key: 'LossType',            label: 'Loss Type',                  value: fmt(d.LossType) },
            { key: 'InitiationDate',      label: 'Initiation Date',            value: fmtDate(d.InitiationDate) },
            { key: 'AssessmentDate',      label: 'Assessment Date',            value: fmtDate(d.AssessmentDate) },
            { key: 'FinalizedDate',       label: 'Finalized Date',             value: fmtDate(d.FinalizedDate) },
            { key: 'Status',              label: 'Status',                     value: fmt(d.Status) },
            { key: 'ClaimReason',         label: 'Claim Reason',               value: fmt(d.ClaimReason) },
            { key: 'IncidentId',          label: 'Incident',                   value: fmt(d.IncidentId) },
            { key: 'TotalAdjustedAmount', label: 'Total Adjusted Amount',      value: fmtCurrency(d.TotalAdjustedAmount) },
        ];
    }

    get aiSummary() {
        const val = this._recordData ? this._recordData.AI_Summary__c : null;
        return (val === null || val === undefined || val === '') ? '—' : String(val);
    }

    // ── ClaimItems ────────────────────────────────────────────────────────────

    get claimItemRows() {
        return (this._claimItems || []).map(ci => ({
            Id:          ci.Id,
            Name:        ci.Name || '—',
            assetName:   (ci.Asset   && ci.Asset.Name)   ? ci.Asset.Name   : fmt(ci.AssetId),
            productName: (ci.Product && ci.Product.Name) ? ci.Product.Name : fmt(ci.ProductId),
            faultDate:   fmtDate(ci.FaultDate),
            description: fmt(ci.Description),
        }));
    }

    get hasClaimItems()       { return !!(this._claimItems && this._claimItems.length > 0); }
    get showItemsEmptyState() { return !!(this._claimItems && this._claimItems.length === 0); }
    get showItemsError()      { return !!this._claimItemsError; }
    get claimItemsErrorMsg()  { return this._claimItemsError?.body?.message || this._claimItemsError?.message || 'Could not load claim items.'; }

    get showItemDetail() { return !!this._selectedItemId; }
    get showItemList()   { return !this._selectedItemId; }

    get selectedItemFieldsLeft() {
        if (!this._selectedItemId || !this._claimItems) return [];
        const ci = this._claimItems.find(x => x.Id === this._selectedItemId);
        if (!ci) return [];
        return [
            { key: 'Name',            label: 'Name',              value: fmt(ci.Name) },
            { key: 'ClaimId',         label: 'Claim',             value: fmt(ci.ClaimId) },
            { key: 'AssetId',         label: 'Asset',             value: (ci.Asset   && ci.Asset.Name)   ? ci.Asset.Name   : fmt(ci.AssetId) },
            { key: 'FaultDate',       label: 'Fault Date',        value: fmtDate(ci.FaultDate) },
            { key: 'AssetUsageValue', label: 'Asset Usage Value', value: fmt(ci.AssetUsageValue) },
            { key: 'VehicleId',       label: 'Vehicle',           value: (ci.Vehicle && ci.Vehicle.Name) ? ci.Vehicle.Name : fmt(ci.VehicleId) },
        ];
    }

    get selectedItemFieldsRight() {
        if (!this._selectedItemId || !this._claimItems) return [];
        const ci = this._claimItems.find(x => x.Id === this._selectedItemId);
        if (!ci) return [];
        return [
            { key: 'Description',               label: 'Description',               value: fmt(ci.Description) },
            { key: 'ProductId',                 label: 'Product',                   value: (ci.Product && ci.Product.Name) ? ci.Product.Name : fmt(ci.ProductId) },
            { key: 'InsurancePolicyCoverageId', label: 'Insurance Policy Coverage', value: (ci.InsurancePolicyCoverage && ci.InsurancePolicyCoverage.Name) ? ci.InsurancePolicyCoverage.Name : fmt(ci.InsurancePolicyCoverageId) },
            { key: 'RepairDate',                label: 'Repair Date',               value: fmtDate(ci.RepairDate) },
            { key: 'AssetUsageUnitOfMeasure',   label: 'Asset Usage Unit',          value: fmt(ci.AssetUsageUnitOfMeasure) },
        ];
    }

    // ── Files ─────────────────────────────────────────────────────────────────

    get claimFileRows() {
        return (this._claimFiles || []).map(f => ({
            contentDocumentId: f.contentDocumentId,
            title:       f.title    || '—',
            fileType:    f.fileType || '—',
            fileSize:    fmtFileSize(f.fileSize),
            createdDate: f.createdDate
                ? new Date(f.createdDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                : '—',
            viewUrl:     f.viewUrl,
            iconName:    fmtFileIcon(f.fileType),
        }));
    }

    get hasClaimFiles()       { return !!(this._claimFiles && this._claimFiles.length > 0); }
    get showFilesEmptyState() { return !!(this._claimFiles && this._claimFiles.length === 0); }
    get showFilesError()      { return !!this._claimFilesError; }
    get claimFilesErrorMsg()  { return this._claimFilesError?.body?.message || this._claimFilesError?.message || 'Could not load files.'; }
}