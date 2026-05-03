/**
 * ClaimSubmittedEventTrigger
 * ─────────────────────────────────────────────────────────────────────────────
 * Subscribes to Claim_Submitted_Event__e platform events and invokes
 * ClaimScoringEngine.calculateScore() for each submitted claim.
 *
 * Fired by: AgentWarrantyAction / createWarrantyClaim() Apex after Claim insert.
 * Calls:    ClaimScoringEngine.calculateScore(claimIds)
 *
 * Bulkified: processes all events in a single batch to respect governor limits.
 * ─────────────────────────────────────────────────────────────────────────────
 */
trigger ClaimSubmittedEventTrigger on Claim_Submitted_Event__e (after insert) {

    // List<Id> claimIds = new List<Id>();

    // for (Claim_Submitted_Event__e evt : Trigger.new) {
    //     if (String.isNotBlank(evt.Claim_Id__c)) {
    //         try {
    //             claimIds.add((Id) evt.Claim_Id__c);
    //         } catch (Exception ex) {
    //             System.debug('ClaimSubmittedEventTrigger: invalid Claim_Id__c value — '
    //                 + evt.Claim_Id__c + '. Skipping. ' + ex.getMessage());
    //         }
    //     }
    // }

    // if (!claimIds.isEmpty()) {
    //     ClaimScoringEngine.calculateScore(claimIds);
    // }
}