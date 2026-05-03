/**
 * ClaimItemTrigger
 * ─────────────────────────────────────────────────────────────────────────────
 * Trigger on standard ClaimItem object.
 * 
 * Automatically recalculates the Confidence Score on the parent Claim 
 * whenever a user adds, updates, or deletes parts/evidence (ClaimItems).
 * ─────────────────────────────────────────────────────────────────────────────
 */
trigger ClaimItemTrigger on ClaimItem (after insert, after update, after delete, after undelete) {
    
    // Collect all parent Claim Ids that need to be rescored
    Set<Id> claimIdsToScore = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (ClaimItem item : Trigger.new) {
            if (item.ClaimId != null) {
                claimIdsToScore.add(item.ClaimId);
            }
        }
    }

    if (Trigger.isDelete || Trigger.isUpdate) {
        for (ClaimItem item : Trigger.old) {
            if (item.ClaimId != null) {
                claimIdsToScore.add(item.ClaimId);
            }
        }
    }

    // Call the engine to recalculate the score for the parent claims
    if (!claimIdsToScore.isEmpty()) {
        List<Id> parentIds = new List<Id>(claimIdsToScore);
        
        // We set the recursion block to true so the ClaimTrigger doesn't infinitely loop
        ClaimScoringEngine.isScoring = true;
        ClaimScoringEngine.calculateScore(parentIds);
        ClaimScoringEngine.isScoring = false;
    }
}