import { api, LightningElement, track } from 'lwc';

export default class HowAreTheyToday extends LightningElement {

    // ── CLT required props ──────────────────────────────────────────────────

    @api
    get readOnly() { return this._readOnly; }
    set readOnly(val) { this._readOnly = val; }
    _readOnly = false;

    @api
    get value() { return this._value; }
    set value(val) {
        this._value = val;
        this._initFromValue(val);
    }
    _value;

    // ── Internal state ──────────────────────────────────────────────────────

    @track selectedMood  = '';
    @track feedbackText  = '';
    @track submitted     = false;
    @track submitError   = '';

    // ── Mood options ────────────────────────────────────────────────────────

    get moodOptions() {
        const moods = [
            { value: 'great',   label: 'Great',   emoji: '😄' },
            { value: 'good',    label: 'Good',    emoji: '🙂' },
            { value: 'neutral', label: 'Neutral', emoji: '😐' },
            { value: 'concerned', label: 'Concerned', emoji: '😟' },
            { value: 'bad',     label: 'Bad',     emoji: '😞' }
        ];
        return moods.map(m => ({
            ...m,
            cssClass: `mood-btn${this.selectedMood === m.value ? ' mood-selected' : ''}`
        }));
    }

    // ── Computed ────────────────────────────────────────────────────────────

    get isEditable()       { return !this._readOnly; }
    get isSubmitDisabled() { return !this.feedbackText.trim() && !this.selectedMood; }

    // ── Init ────────────────────────────────────────────────────────────────

    _initFromValue(val) {
        if (!val) return;
        this.selectedMood = val.selectedMood  || '';
        this.feedbackText = val.feedbackText  || '';
    }

    // ── Handlers ────────────────────────────────────────────────────────────

    handleMoodSelect(e) {
        this.selectedMood = e.currentTarget.dataset.value;
        this._dispatchChange();
    }

    handleTextChange(e) {
        this.feedbackText = e.target.value;
        this._dispatchChange();
    }

    handleSubmit() {
        if (!this.feedbackText.trim() && !this.selectedMood) {
            this.submitError = 'Please enter details or select a mood before submitting.';
            return;
        }
        this.submitError = '';
        this.submitted   = true;
        this._dispatchChange(true);
    }

    // ── Dispatch ────────────────────────────────────────────────────────────

    _dispatchChange(submitRequested = false) {
        // Build the combined text that will be saved to Account Description
        const moodLine    = this.selectedMood
            ? `Mood: ${this.selectedMood}\n`
            : '';
        const combined    = `${moodLine}${this.feedbackText}`.trim();

        this.dispatchEvent(new CustomEvent('valuechange', {
            bubbles:  false,
            composed: false,
            detail: {
                value: {
                    selectedMood:    this.selectedMood,
                    feedbackText:    this.feedbackText,
                    combinedFeedback: combined,
                    submitRequested: submitRequested ? 'true' : 'false'
                }
            }
        }));
    }
}