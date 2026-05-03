import { LightningElement, track } from 'lwc';
import getClaims from '@salesforce/apex/ClaimListController.getClaims';

const PAGE_SIZE = 10;

const DATE_FILTER_DEFS = [
    { label: 'Today',      value: 'TODAY'      },
    { label: 'Yesterday',  value: 'YESTERDAY'  },
    { label: 'This Month', value: 'THIS_MONTH' },
    { label: 'Last Month', value: 'LAST_MONTH' },
];

const STATUS_FILTER_DEFS = [
    { label: 'All',         value: ''            },
    { label: 'New',         value: 'New'         },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Approved',    value: 'Approved'    },
];

function getStatusClass(status) {
    if (!status) return 'status-gray';
    const s = status.toLowerCase();
    if (s === 'approved')    return 'status-green';
    if (s === 'in progress') return 'status-blue';
    if (s === 'new')         return 'status-amber';
    if (s === 'rejected' || s === 'denied') return 'status-red';
    return 'status-gray';
}

function formatCurrency(val) {
    if (val == null || val === '') return '—';
    try {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(val);
    } catch (e) {
        return String(val);
    }
}

export default class ClaimList extends LightningElement {

    @track claims          = [];
    @track isLoading       = false;
    @track loadError       = null;
    @track selectedClaimId = null;

    dateFilter   = 'THIS_MONTH';
    statusFilter = '';
    searchTerm   = '';
    currentPage  = 1;
    _searchDebounce = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadClaims();
    }

    // ── Data Loading ──────────────────────────────────────────────────────────

    async loadClaims() {
        this.isLoading = true;
        this.loadError = null;
        try {
            this.claims = await getClaims({
                dateFilter:   this.dateFilter,
                statusFilter: this.statusFilter,
                searchTerm:   this.searchTerm,
            });
        } catch (e) {
            this.loadError = (e.body && e.body.message) ? e.body.message : 'Error loading records.';
            this.claims = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Filter Handlers ───────────────────────────────────────────────────────

    handleDateFilterClick(event) {
        this.dateFilter = event.currentTarget.dataset.value;
        this.currentPage = 1;
        this.loadClaims();
    }

    handleStatusFilterClick(event) {
        this.statusFilter = event.currentTarget.dataset.value;
        this.currentPage = 1;
        this.loadClaims();
    }

    handleSearchChange(event) {
        const value = event.target.value;
        clearTimeout(this._searchDebounce);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchDebounce = setTimeout(() => {
            this.searchTerm = value;
            this.currentPage = 1;
            this.loadClaims();
        }, 300);
    }

    // ── Row Navigation ────────────────────────────────────────────────────────

    handleViewClick(event) {
        this.selectedClaimId = event.currentTarget.dataset.id;
    }

    handleBack() {
        this.selectedClaimId = null;
        this.loadClaims();
    }

    // ── Pagination ────────────────────────────────────────────────────────────

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage -= 1;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage += 1;
    }

    // ── Computed Getters ──────────────────────────────────────────────────────

    get dateFilterButtons() {
        return DATE_FILTER_DEFS.map(d => ({
            label:    d.label,
            value:    d.value,
            btnClass: 'filter-btn' + (d.value === this.dateFilter ? ' filter-btn-active' : ''),
        }));
    }

    get statusFilterButtons() {
        return STATUS_FILTER_DEFS.map(s => ({
            label:    s.label,
            value:    s.value,
            btnClass: 'filter-btn' + (s.value === this.statusFilter ? ' filter-btn-active' : ''),
        }));
    }

    get hasRecords() {
        return this.claims && this.claims.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.loadError && !this.hasRecords;
    }

    get showTable() {
        return !this.isLoading && !this.loadError && this.hasRecords;
    }

    get recordCountLabel() {
        const n = this.claims ? this.claims.length : 0;
        return `${n} record${n === 1 ? '' : 's'}`;
    }

    get claimsWithMeta() {
        return (this.claims || []).map(c => ({
            Id:              c.Id,
            Name:            c.Name || '—',
            accountName:     (c.Account && c.Account.Name) ? c.Account.Name : '—',
            Status:          c.Status || '—',
            ClaimType:       c.ClaimType || '—',
            formattedAmount: formatCurrency(c.EstimatedAmount),
            formattedDate:   c.CreatedDate
                ? new Date(c.CreatedDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                : '—',
            statusBadgeClass: 'status-badge ' + getStatusClass(c.Status),
        }));
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.claimsWithMeta.length / PAGE_SIZE));
    }

    get pagedClaims() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.claimsWithMeta.slice(start, start + PAGE_SIZE);
    }

    get paginationLabel() {
        const total = this.claimsWithMeta.length;
        if (total === 0) return '0 records';
        const start = (this.currentPage - 1) * PAGE_SIZE + 1;
        const end   = Math.min(this.currentPage * PAGE_SIZE, total);
        return `${start}–${end} of ${total}`;
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get showListView()   { return !this.selectedClaimId; }
    get showDetailView() { return !!this.selectedClaimId; }
}