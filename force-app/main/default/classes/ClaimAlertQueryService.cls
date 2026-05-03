/**
 * ClaimAlertQueryService
 * ─────────────────────────────────────────────────────────────────────────────
 * Queries Claim records in Pending / Under Review / Under Investigation status
 * and splits the count across the three scoring scenarios:
 *   Scenario 1 → AUTO_APPROVE band  (score 85–100) — queued for approval
 *   Scenario 2 → HUMAN_REVIEW band  (score 40–84)  — waiting on an adjuster
 *   Scenario 3 → INVESTIGATE band   (score 0–39)   — fraud / escalation queue
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class ClaimAlertQueryService {

    /** Holds the three scenario counts returned to the caller. */
    public class ClaimCounts {
        public Integer totalPending    { get; set; }
        public Integer scenario1Count  { get; set; }  // AUTO_APPROVE — score >= 85
        public Integer scenario2Count  { get; set; }  // HUMAN_REVIEW — score 40-84
        public Integer scenario3Count  { get; set; }  // INVESTIGATE  — score 0-39
        public Datetime asOf           { get; set; }

        public ClaimCounts() {
            totalPending   = 0;
            scenario1Count = 0;
            scenario2Count = 0;
            scenario3Count = 0;
            asOf           = Datetime.now();
        }
    }

    /**
     * Main method — returns a populated ClaimCounts object.
     * Called by ClaimAlertScheduler.execute().
     */
    public static ClaimCounts getPendingClaimCounts() {
        ClaimCounts counts = new ClaimCounts();

        // ── Query all pending claims with their confidence scores ─────────────
        // Statuses that mean "waiting for action" in this org:
        //   'New'                → just scored, not yet routed
        //   'Under Review'       → HUMAN_REVIEW routing decision
        //   'Under Investigation'→ INVESTIGATE routing decision
        //   'Submitted'          → re-submitted after adjuster review
        List<Claim> pendingClaims = [
            SELECT Id,
                   Confidence_Score__c,
                   Auto_Approved__c,
                   Fruad_Flag__c,
                   Status
            FROM   Claim
            WHERE  Status IN ('New', 'Under Review', 'Under Investigation', 'Submitted')
            ORDER BY CreatedDate DESC
        ];

        counts.totalPending = pendingClaims.size();

        for (Claim c : pendingClaims) {
            Integer score = (Integer)(c.Confidence_Score__c ?? 0);

            if (score >= 85) {
                counts.scenario1Count++;   // AUTO_APPROVE band
            } else if (score >= 40) {
                counts.scenario2Count++;   // HUMAN_REVIEW band
            } else {
                counts.scenario3Count++;   // INVESTIGATE band
            }
        }

        return counts;
    }
}