/**
 * ClaimTrigger
 * ─────────────────────────────────────────────────────────────────────────────
 * Trigger on standard Claim object.
 * 
 * Bypasses the Platform Event and calls the Scoring Engine directly.
 * - Fires on INSERT so newly created claims get a baseline score immediately.
 * - Fires on UPDATE if a user changes the Status to 'Submitted' (after parts are added).
 * ─────────────────────────────────────────────────────────────────────────────
 */
trigger ClaimTrigger on Claim (after insert, after update) {

    // ── Approval Email Notification ───────────────────────────────────────────
    // Runs BEFORE the reentrancy guard so it fires whether Status becomes
    // 'Approved' via direct DML or via ClaimScoringEngine's auto-approval update.
    List<Id> toNotify = new List<Id>();

    for (Claim c : Trigger.new) {
        if (Trigger.isInsert && c.Status == 'Approved') {
            toNotify.add(c.Id);
        } else if (Trigger.isUpdate) {
            Claim oldClaim = Trigger.oldMap.get(c.Id);
            if (c.Status == 'Approved' && oldClaim.Status != 'Approved') {
                toNotify.add(c.Id);
            }
        }
    }

    if (!toNotify.isEmpty()) {
        ClaimApprovalNotifier.sendApprovalEmails(toNotify);
    }

    // ── Prevent infinite loop since the Scoring Engine does a DML update on the Claim
    if (ClaimScoringEngine.isScoring) {
        return;
    }

    List<Id> claimsToScore = new List<Id>();

    for (Claim c : Trigger.new) {
        if (Trigger.isInsert) {
            // Score immediately when created
            claimsToScore.add(c.Id);
        }
        else if (Trigger.isUpdate) {
            Claim oldClaim = Trigger.oldMap.get(c.Id);

            // Re-score if a user manually flips the status to 'Submitted'
            if (c.Status == 'Submitted' && oldClaim.Status != 'Submitted') {
                claimsToScore.add(c.Id);
            }
        }
    }

    if (!claimsToScore.isEmpty()) {
        ClaimScoringEngine.isScoring = true;
        ClaimScoringEngine.calculateScore(claimsToScore);
        ClaimScoringEngine.isScoring = false;
    }
}