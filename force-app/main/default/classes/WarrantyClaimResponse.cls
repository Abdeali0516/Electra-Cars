/**
 * WarrantyClaimResponse
 * ─────────────────────────────────────────────────────────────────────────────
 * Agentforce Custom Lightning Type (CLT) — OUTPUT schema.
 * Scoped to the fields returned after Claim record creation only.
 *
 * CLAIM SOBJECT FIELDS RETURNED:
 *   Claim.Id          → claimId
 *   Claim.Name        → claimNumber  (auto-number display field e.g. "C-00001")
 *   Claim.Status      → claimStatus  (field API name is Status, not ClaimStatus)
 *   Claim.ClaimType   → claimType
 *   Claim.ClaimReason → claimDescription
 *
 * FIELD NOTES:
 *   ✅ Claim.Name   — auto-number field, populated after insert (re-queried)
 *   ✅ Claim.Status — API field name is Status (NOT ClaimStatus)
 *   ❌ ClaimNumber  — NOT a field on Claim SObject
 *   ❌ ClaimStatus  — NOT a field on Claim SObject; correct API name is Status
 *   ❌ TotalClaimedAmount / TotalApprovedAmount — NOT standard Claim fields
 *
 * API VERSION: 62.0 (Spring '26)
 * ─────────────────────────────────────────────────────────────────────────────
 */
global class WarrantyClaimResponse {

    /**
     * Claim.Id
     * Salesforce record Id of the newly created Claim.
     */
    @InvocableVariable(label='Claim Id' required=false)
    global Id claimId;

    /**
     * Claim.Name
     * Auto-number display field — the human-readable claim reference
     * shown to the customer (e.g. "C-00001").
     * NOTE: The SObject field is Name, not ClaimNumber.
     * Re-queried after insert: SELECT Id, Name FROM Claim WHERE Id = :claim.Id
     */
    @InvocableVariable(label='Claim Number' required=false)
    global String claimNumber;

    /**
     * Claim.Status
     * Current status of the Claim record after creation.
     * NOTE: The SObject field API name is Status, not ClaimStatus.
     * Value after insert: 'New'
     */
    @InvocableVariable(label='Claim Status' required=false)
    global String claimStatus;

    /**
     * Claim.ClaimType
     * Type of claim — hardcoded to 'Warranty Claim' on creation.
     */
    @InvocableVariable(label='Claim Type' required=false)
    global String claimType;

    /**
     * Date the claim was submitted (Date.today() at submission time).
     * Stored in the response DTO — there is no ClaimDate field on Claim SObject.
     */
    @InvocableVariable(label='Claim Date' required=false)
    global Date claimDate;

    /**
     * Claim.ClaimReason
     * The value set on Claim.ClaimReason:
     * affectedComponent + ': ' + faultDescription.
     */
    @InvocableVariable(label='Claim Description' required=false)
    global String claimDescription;

    /**
     * Formatted timestamp of when the claim was submitted.
     * Format: 'dd MMM yyyy, hh:mm a z'
     */
    @InvocableVariable(label='Submission Timestamp' required=false)
    global String submissionTimestamp;
}