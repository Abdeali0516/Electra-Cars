import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STATUS_FIELD from '@salesforce/schema/Claim.Status';

const FIELDS = [STATUS_FIELD];

// Ordered steps — matches standard Automotive Cloud warranty claim lifecycle
const STEPS = [
    { value: 'New',         label: 'New'         },
    { value: 'In Progress', label: 'In Progress' },
    { value: 'Approved',    label: 'Approved'    }
];

// Status values treated as rejected/denied — shown at last step with error styling
const REJECTED = new Set(['rejected', 'denied']);

// Map alias status values onto canonical step values
const ALIASES = {
    'draft':        'New',
    'open':         'New',
    'under review': 'In Progress',
    'processing':   'In Progress',
    'closed':       'Approved',
    'settled':      'Approved',
    'rejected':     'Approved',
    'denied':       'Approved'
};

export default class ClaimStatusPath extends LightningElement {
    @api recordId;

    // When a parent component already has the status value (e.g. loaded via Apex),
    // pass it here to skip the getRecord wire entirely — avoids UI API access issues
    // on Experience Cloud for community users.
    @api statusValue;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    // ── Whether we're in direct-value mode or wire mode ───────────────────────
    get _isDirect() { return !!this.statusValue; }

    // ── State ─────────────────────────────────────────────────────────────────
    get isLoading()    {
        if (this._isDirect) return false;
        return !this.record.data && !this.record.error;
    }
    get isLoaded()     {
        if (this._isDirect) return true;
        return !!this.record.data;
    }
    get hasLoadError() {
        if (this._isDirect) return false;
        return !!this.record.error;
    }
    get loadError()    { return this.record?.error?.body?.message || 'Could not load claim status.'; }

    // ── Status value ──────────────────────────────────────────────────────────
    get status() {
        if (this._isDirect) return this.statusValue || '—';
        return getFieldValue(this.record.data, STATUS_FIELD) || '—';
    }

    get isRejected() {
        return REJECTED.has((this.status || '').toLowerCase());
    }

    // ── Canonical step the current status maps to ─────────────────────────────
    get _currentStepValue() {
        const raw = (this.status || '').toLowerCase();
        if (ALIASES[raw]) return ALIASES[raw];
        const exact = STEPS.find(s => s.value.toLowerCase() === raw);
        return exact ? exact.value : STEPS[0].value;
    }

    // ── Steps enriched with display state ────────────────────────────────────
    get stepsWithState() {
        const currentValue = this._currentStepValue;
        const currentIndex = STEPS.findIndex(s => s.value === currentValue);

        return STEPS.map((s, i) => {
            const isCompleted = i < currentIndex;
            const isCurrent   = i === currentIndex;
            const isFuture    = i > currentIndex;
            const isFirst     = i === 0;

            let nodeClass = 'csp-node';
            if (isCompleted)                          nodeClass += ' csp-node-done';
            else if (isCurrent && this.isRejected)    nodeClass += ' csp-node-error';
            else if (isCurrent)                       nodeClass += ' csp-node-current';
            else                                      nodeClass += ' csp-node-future';

            let lineClass = 'csp-connector';
            if (isFirst)        lineClass += ' csp-connector-hidden';
            else if (isCompleted || isCurrent) lineClass += ' csp-connector-done';
            else                lineClass += ' csp-connector-future';

            let stepClass = 'csp-step';
            if (isCurrent)   stepClass += ' csp-step-current';
            if (isCompleted) stepClass += ' csp-step-done';
            if (isFuture)    stepClass += ' csp-step-future';

            const isLast = i === STEPS.length - 1;
            const showCheck = isCompleted || (isCurrent && isLast && !this.isRejected);

            return {
                ...s,
                index:       i + 1,
                isCompleted,
                isCurrent,
                isFuture,
                showCheck,
                nodeClass,
                lineClass,
                stepClass
            };
        });
    }

    // ── Progress fill bar class (step index → fixed-width CSS class) ─────────
    get fillBarClass() {
        const idx = STEPS.findIndex(s => s.value === this._currentStepValue);
        const map = { 0: 'csp-fill-0', 1: 'csp-fill-50', 2: 'csp-fill-100' };
        return 'csp-fill-bar ' + (map[idx] || 'csp-fill-0');
    }

    // ── Badge CSS ─────────────────────────────────────────────────────────────
    get statusBadgeClass() {
        const s = (this.status || '').toLowerCase();
        if (s === 'draft' || s === 'new' || s === 'open')
            return 'csp-badge csp-badge-open';
        if (s === 'in progress' || s === 'under review' || s === 'processing')
            return 'csp-badge csp-badge-progress';
        if (s === 'approved' || s === 'closed' || s === 'settled')
            return 'csp-badge csp-badge-closed';
        if (s === 'rejected' || s === 'denied')
            return 'csp-badge csp-badge-rejected';
        return 'csp-badge csp-badge-neutral';
    }
}