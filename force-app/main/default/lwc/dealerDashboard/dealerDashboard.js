import { LightningElement, wire, track } from 'lwc';
import getDashboardData from '@salesforce/apex/DealerDashboardController.getDashboardData';

export default class DealerDashboard extends LightningElement {

    @track data       = null;
    @track errorMessage = null;

    @wire(getDashboardData)
    wiredData({ data, error }) {
        if (data) {
            this.data         = data;
            this.errorMessage = null;
        } else if (error) {
            this.errorMessage = (error?.body?.message) || (error?.message) || 'An unexpected error occurred.';
            this.data         = null;
        }
    }

    // ── State getters ─────────────────────────────────────────────────────────
    get isLoading()    { return !this.data && !this.errorMessage; }
    get hasError()     { return !!this.errorMessage; }
    get hasData()      { return !!this.data; }
    get hasClaims()    { return this.data?.claims?.length    > 0; }
    get hasClaimItems(){ return this.data?.claimItems?.length > 0; }
    get hasVehicles()  { return this.data?.vehicles?.length  > 0; }

    // ── KPI strip ─────────────────────────────────────────────────────────────
    get kpiCards() {
        if (!this.data) return [];
        return [
            { label: 'Total Vehicles',    value: this.data.totalVehicles,    icon: '🚗' },
            { label: 'Active Warranties', value: this.data.activeWarranties, icon: '🛡️' },
            { label: 'Open Claims',       value: this.data.openClaims,       icon: '📋' },
            { label: 'Claim Items',       value: this.data.totalClaimItems,  icon: '🔩' }
        ];
    }

    // ── Date label ────────────────────────────────────────────────────────────
    get todayLabel() {
        return new Date().toLocaleDateString('en-IN', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
        });
    }
}