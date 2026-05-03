/**
 * ContentDocumentLinkTrigger
 * ─────────────────────────────────────────────────────────────────────────────
 * Re-scores the parent Claim whenever a file or note is attached/removed.
 * Fires on ContentDocumentLink — the junction object created when any file
 * (ContentVersion) or note (ContentNote) is linked to a record.
 * ─────────────────────────────────────────────────────────────────────────────
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert, after delete) {

    Set<Id> claimIdsToScore = new Set<Id>();

    List<ContentDocumentLink> links = Trigger.isDelete ? Trigger.old : Trigger.new;

    for (ContentDocumentLink cdl : links) {
        // LinkedEntityId is the record the file was attached to
        // Only care about Claim records (prefix 0OA for standard Claim)
        if (cdl.LinkedEntityId != null &&
            cdl.LinkedEntityId.getSObjectType() == Claim.SObjectType) {
            claimIdsToScore.add(cdl.LinkedEntityId);
        }
    }

    if (!claimIdsToScore.isEmpty()) {
        ClaimScoringEngine.isScoring = true;
        ClaimScoringEngine.calculateScore(new List<Id>(claimIdsToScore));
        ClaimScoringEngine.isScoring = false;
    }
}