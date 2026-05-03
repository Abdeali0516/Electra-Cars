import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class WarrantyCustomerProfile extends NavigationMixin(LightningElement) {

    @track _profile = {};

    @api
    get value() {
        return this._profile;
    }
    set value(v) {
        try {
            // Agentforce may pass a JSON string or a plain object
            if (typeof v === 'string') {
                this._profile = JSON.parse(v);
            } else if (v && typeof v === 'object') {
                this._profile = Object.assign({}, v);
            }
        } catch (e) {
            console.error('WarrantyCustomerProfile: failed to parse value', e);
            this._profile = {};
        }
    }

    // ── Derived getters ─────────────────────────────────────────────

    get hasProfile() {
        return !!(this._profile && (this._profile.vin || this._profile.vehicleName));
    }

    get isEligible() {
        return ['ELIGIBLE', 'ELIGIBLE_VIA_CONTRACT'].includes(this._profile.warrantyStatus);
    }

    get hasClaimId() {
        return !!this._profile.claimId;
    }

    get statusLabel() {
        const map = {
            'ELIGIBLE':              'Eligible',
            'ELIGIBLE_VIA_CONTRACT': 'Eligible (Contract)',
            'EXPIRED':               'Warranty Expired',
            'NO_WARRANTY':           'No Warranty',
            'NOT_FOUND':             'Vehicle Not Found',
            'MILEAGE_EXCEEDED':      'Mileage Exceeded',
            'ERROR':                 'Error'
        };
        return map[this._profile.warrantyStatus] || this._profile.warrantyStatus || '—';
    }

    get vin()              { return this._profile.vin              || '—'; }
    get vehicleName()      { return this._profile.vehicleName      || '—'; }
    get chassisNumber()    { return this._profile.chassisNumber    || '—'; }
    get stockCode()        { return this._profile.stockCode        || '—'; }
    get vehicleStatus()    { return this._profile.vehicleStatus    || '—'; }
    get engineNumber()     { return this._profile.engineNumber     || '—'; }
    get exteriorColor()    { return this._profile.exteriorColor    || '—'; }
    get interiorColor()    { return this._profile.interiorColor    || '—'; }
    get gearBoxType()      { return this._profile.gearBoxType      || '—'; }
    get manufacturedDate() { return this._profile.manufacturedDate || '—'; }
    get lastServiceDate()  { return this._profile.lastServiceDate  || '—'; }
    get warrantyStart()    { return this._profile.warrantyStart    || 'Not configured'; }
    get warrantyEnd()      { return this._profile.warrantyEnd      || 'Not configured'; }
    get activeContracts()  { return this._profile.activeContracts  ?? '—'; }
    get activeWarranty()   { return this._profile.activeWarranty   ?? '—'; }
    get claimCount()       { return this._profile.claimCount       ?? 0; }
    get ownerName()        { return this._profile.ownerName        || '—'; }
    get ownerPhone()       { return this._profile.ownerPhone       || '—'; }
    get ownerEmail()       { return this._profile.ownerEmail       || '—'; }
    get ownerCity()        { return this._profile.ownerCity        || '—'; }
    get ownerState()       { return this._profile.ownerState       || '—'; }
    get dealerName()       { return this._profile.dealerName       || '—'; }

    get colorAndModel() {
        const name  = this._profile.vehicleName  || '—';
        const color = this._profile.exteriorColor;
        return color ? `${name} — ${color}` : name;
    }

    get warranties() {
        return (this._profile.warranties || []).map(w => ({
            warrantyType:     w.warrantyType || '—',
            endDateFormatted: w.endDate
                ? new Date(w.endDate).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
                : '—',
            mileageDisplay: w.mileageLimit
                ? `${Number(w.mileageLimit).toLocaleString()} mi`
                : null,
            key: (w.warrantyType || '') + (w.endDate || '')
        }));
    }

    get hasWarranties() { return this.warranties.length > 0; }

    get mileageDisplay() {
        return this._profile.reportedMileage
            ? `${Number(this._profile.reportedMileage).toLocaleString()} km`
            : 'Not provided';
    }

    get bannerClass() {
        return this.isEligible
            ? 'wcp-banner wcp-banner--success'
            : 'wcp-banner wcp-banner--error';
    }

    get pillClass() {
        if (this.isEligible) return 'wcp-pill wcp-pill--green';
        if (['EXPIRED', 'MILEAGE_EXCEEDED'].includes(this._profile.warrantyStatus)) return 'wcp-pill wcp-pill--red';
        return 'wcp-pill wcp-pill--gray';
    }

    get eligibilityTextClass() {
        return this.isEligible ? 'wcp-val wcp-val--eligible' : 'wcp-val wcp-val--ineligible';
    }

    openClaim() {
        if (!this._profile.claimId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this._profile.claimId, actionName: 'view' }
        });
    }
}