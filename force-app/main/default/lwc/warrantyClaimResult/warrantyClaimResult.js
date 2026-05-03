/**
 * warrantyClaimResult — Agentforce OUTPUT (Renderer) LWC
 * ─────────────────────────────────────────────────────────────────────────────
 * Target: lightning__AgentforceOutput
 *
 * Per official Salesforce docs (lightning-types-example-full-editor-renderer.html):
 *   - Use @api value to receive the action output from Agentforce.
 *   - The `value` object properties map 1:1 to WarrantyClaimResponse @InvocableVariable names.
 *   - Renderers are READ-ONLY — no valuechange event needed.
 *   - Agentforce passes the complete WarrantyClaimResponse object as `value`.
 *
 * FIELD MAPPING (value.xxx → Apex WarrantyClaimResponse field):
 *   value.claimNumber          ← claimNumber  (Claim.Name auto-number)
 *   value.claimStatus          ← claimStatus  (Claim.Status)
 *   value.claimItemStatus      ← claimItemStatus (ClaimItem.Status)
 *   value.coverageDecision     ← coverageDecision
 *   value.coverageNotes        ← coverageNotes
 *   value.coverageType         ← coverageType (ClaimCoverage.CoverageType)
 *   value.workOrderNumber      ← workOrderNumber
 *   value.assignedDealerName   ← assignedDealerName
 *   value.assignedDealerAddress← assignedDealerAddress
 *   value.assignedDealerPhone  ← assignedDealerPhone
 *   value.isRSAEligible        ← isRSAEligible
 *   value.rsaContactNumber     ← rsaContactNumber
 *   value.rsaMaxTowDistanceKm  ← rsaMaxTowDistanceKm
 *   value.submissionTimestamp  ← submissionTimestamp
 *   value.estimatedCompletionDate ← estimatedCompletionDate
 *   value.nextSteps            ← nextSteps
 *   value.replacedPartsWarrantyMonths ← replacedPartsWarrantyMonths
 *   value.replacedPartsWarrantyKm     ← replacedPartsWarrantyKm
 * ─────────────────────────────────────────────────────────────────────────────
 */
import { LightningElement, api } from 'lwc';

export default class WarrantyClaimResult extends LightningElement {

    /**
     * @api value — populated by Agentforce with the WarrantyClaimResponse output.
     * Required by the lightning__AgentforceOutput target contract.
     */
    @api value = {};

    // ── Status header class ────────────────────────────────────────────────────

    get statusHeaderClass() {
        const base = 'status-header';
        const decision = this.value && this.value.coverageDecision;
        if (decision === 'Covered')           return `${base} status-covered`;
        if (decision === 'Partially Covered') return `${base} status-partial`;
        if (decision === 'Not Covered')       return `${base} status-rejected`;
        return `${base} status-pending`;
    }

    get statusIcon() {
        const decision = this.value && this.value.coverageDecision;
        if (decision === 'Covered')           return '✅';
        if (decision === 'Partially Covered') return '⚠️';
        if (decision === 'Not Covered')       return '❌';
        return '⏳';
    }

    get coverageBadgeClass() {
        const base = 'coverage-badge';
        const decision = this.value && this.value.coverageDecision;
        if (decision === 'Covered')           return `${base} badge-covered`;
        if (decision === 'Partially Covered') return `${base} badge-partial`;
        if (decision === 'Not Covered')       return `${base} badge-rejected`;
        return `${base} badge-pending`;
    }
}