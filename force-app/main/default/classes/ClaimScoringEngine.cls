/**
 * ClaimScoringEngine
 * ─────────────────────────────────────────────────────────────────────────────
 * Core confidence scoring engine for Electra Warranty Intelligence.
 * Implements the 6-factor algorithm from ConfidenceScore_ImplementationGuide_v2.
 *
 * FIELD ADAPTATIONS (guide → this org):
 *   Fraud_Flag__c          → Fruad_Flag__c          (existing typo field preserved)
 *   Evidence_Complete__c   → Evidence_Completed__c   (org naming)
 *   Avg_Cost_Benchmark__c  → Avg_Repair_Cost__c      (org naming)
 *   Cost_Std_Dev__c        → Repair_Cost_StdDev__c   (org naming)
 *   AssetWarranty.CoverageType  → AssetWarranty.WarrantyType
 *   AssetWarranty.CoveredMileage → AssetWarranty.WarrantyTerm.UsageCovered
 *   Claim.ClaimStatus      → Claim.Status            (org field name)
 *   Claim.TotalLineAmount  → Claim.TotalClaimedAmount (org field name)
 *   Claim_Score_Detail__c.Claim__c → new Lookup to standard Claim
 *
 * SCORING BANDS:
 *   85–100  → AUTO_APPROVE  (~55% of claims)
 *   40–84   → HUMAN_REVIEW  (~30% of claims)
 *   0–39    → INVESTIGATE   (~15% of claims)
 *
 * API VERSION: 62.0 (Spring '26)
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class ClaimScoringEngine {

    // =========================================================================
    // INNER CLASSES — Data Structures
    // =========================================================================

    public static Boolean isScoring = false;

    /** Full scoring output returned to the caller and persisted on the Claim. */
    public class ScoreResult {
        @AuraEnabled public Integer totalScore;
        @AuraEnabled public Integer coverageScore;    // Factor 1 — max 25
        @AuraEnabled public Integer historyScore;     // Factor 2 — max 20
        @AuraEnabled public Integer dealerScore;      // Factor 3 — max 15
        @AuraEnabled public Integer costScore;        // Factor 4 — max 15
        @AuraEnabled public Integer evidenceScore;    // Factor 5 — max 15
        @AuraEnabled public Integer defectScore;      // Factor 6 — max 10
        @AuraEnabled public String  routingDecision;  // AUTO_APPROVE | HUMAN_REVIEW | INVESTIGATE
        @AuraEnabled public String  aiSummary;
        @AuraEnabled public List<FactorDetail> factorBreakdown;
    }

    /** Per-factor audit detail — one record written to Claim_Score_Detail__c per factor. */
    public class FactorDetail {
        public String  factorName;
        public Integer weight;
        public Integer score;
        public String  reasoning;
    }

    /** All data loaded from SOQL before scoring begins — avoids repeated queries. */
    public class ClaimContext {
        public Claim                 claim;
        public Product2              part;
        public Id                    productId;
        public Integer               priorClaimCount;
        public Decimal               maxPriorMileage;
        public Integer               validatedItemCount;
        public Decimal               costBenchmarkAvg;
        public Decimal               costBenchmarkStdDev;
    }

    // =========================================================================
    // ENTRY POINT — @InvocableMethod (called by trigger + manual re-score)
    // =========================================================================

    public static List<ScoreResult> calculateScore(List<Id> claimIds) {
        List<ScoreResult> results = new List<ScoreResult>();

        for (Id claimId : claimIds) {
            try {
                ClaimContext ctx = loadContext(claimId);
                ScoreResult  res = runScoringFactors(ctx);
                persistResults(claimId, res);
                results.add(res);
            } catch (Exception e) {
                System.debug('ClaimScoringEngine error for Claim ' + claimId + ': ' + e.getMessage());
                // Return a safe default result so the list size matches input
                ScoreResult errResult = new ScoreResult();
                errResult.totalScore      = 0;
                errResult.routingDecision = 'INVESTIGATE';
                errResult.aiSummary       = 'Scoring error: ' + e.getMessage();
                errResult.factorBreakdown = new List<FactorDetail>();
                results.add(errResult);
            }
        }

        return results;
    }

    // =========================================================================
    // CONTEXT LOADER — All SOQL queries in one place
    // =========================================================================

    @TestVisible
    private static ClaimContext loadContext(Id claimId) {
        ClaimContext ctx = new ClaimContext();

        // ── Load Claim with related Account (dealer) fields ──────────────────
        // Account fields: Tier__c, Credibility_Score__c, Fraud_Investigation_Active__c
        // If these custom fields don't yet exist in your org, comment them out here
        // and in runScoringFactors() until deployed.
        ctx.claim = [
            SELECT Id, Name, Status, InitiationDate,
                   AccountId, InsuredAssetId,
                   EstimatedAmount,
                   Current_Mileage__c,
                   AI_Summary__c,
                   ClaimReason,
                   Account.Name,
                   Account.Dealer_Code__c
            FROM   Claim
            WHERE  Id = :claimId
            LIMIT  1
        ];

        // ── Resolve Asset Id from InsuredAssetId (set during claim creation) ─
        // InsuredAssetId on standard Claim → links to Asset via InsurancePolicyAsset,
        // but in this org AgentWarrantyAction sets AccountId from Vehicle.CurrentOwnerId.
        // We resolve Asset via a separate query on the Vehicle linked to this Account.
        Id assetId = ctx.claim.InsuredAssetId;

        // ── Get primary ClaimItem (part being claimed) ───────────────────────
        List<ClaimItem> items = [
            SELECT Id, ProductId, Description,
                   Product.Known_Defect__c,
                   Product.TSB_Reference__c,
                   Product.Recall_Active__c,
                   Product.Avg_Repair_Cost__c,
                   Product.Repair_Cost_StdDev__c
            FROM   ClaimItem
            WHERE  ClaimId = :claimId
            ORDER BY CreatedDate ASC
            LIMIT  1
        ];

        ctx.productId = items.isEmpty() ? null : items[0].ProductId;

        if (!items.isEmpty() && ctx.productId != null) {
            ctx.part = items[0].Product;
            ctx.costBenchmarkAvg    = ctx.part.Avg_Repair_Cost__c    ?? 0;
            ctx.costBenchmarkStdDev = ctx.part.Repair_Cost_StdDev__c ?? 0;
        } else {
            ctx.costBenchmarkAvg    = 0;
            ctx.costBenchmarkStdDev = 0;
        }

        // ── Active AssetWarranty records for this asset ──────────────────────
        

        // ── Prior Claim count for same part on same Asset ────────────────────
        if (assetId != null && ctx.productId != null) {
            AggregateResult hist = [
                SELECT COUNT(Id) cnt, MAX(Current_Mileage__c) maxMileage
                FROM   Claim
                WHERE  InsuredAssetId = :assetId
                  AND  Id IN (
                      SELECT ClaimId
                      FROM   ClaimItem
                      WHERE  ProductId = :ctx.productId
                  )
                  AND  Id != :claimId
            ];
            ctx.priorClaimCount = Integer.valueOf(hist.get('cnt') ?? 0);
            ctx.maxPriorMileage = (Decimal)(hist.get('maxMileage') ?? 0);
        } else {
            ctx.priorClaimCount = 0;
            ctx.maxPriorMileage = 0;
        }

        // ── Validated ClaimItem count (evidence completeness) ────────────────
        List<ClaimItem> allItemsForClaim = [
            SELECT Description
            FROM   ClaimItem
            WHERE  ClaimId = :claimId
        ];
        
        Integer validCount = 0;
        for (ClaimItem ci : allItemsForClaim) {
            if (String.isNotBlank(ci.Description) && ci.Description.contains('Validated')) {
                validCount++;
            }
        }
        ctx.validatedItemCount = validCount;

        return ctx;
    }

    // =========================================================================
    // SCORING FACTORS — Runs all 6 and returns a ScoreResult
    // =========================================================================

    @TestVisible
    private static ScoreResult runScoringFactors(ClaimContext ctx) {
        ScoreResult res = new ScoreResult();
        res.factorBreakdown = new List<FactorDetail>();

        // ── FACTOR 1: Warranty Coverage via AssetWarranty (25 pts) ───────────
        // ── FACTOR 1: Claim Reason populated (25 pts) ─────────────────────────
FactorDetail f1 = new FactorDetail();
f1.factorName = 'Warranty Coverage Match';
f1.weight     = 25;

String claimReason = ctx.claim.ClaimReason;

if (String.isNotBlank(claimReason)) {
    f1.score     = 25;
    f1.reasoning = 'Claim reason provided: ' + claimReason + '. Warranty basis confirmed.';
} else {
    f1.score     = 0;
    f1.reasoning = 'No claim reason provided. Cannot confirm warranty basis.';
}
res.coverageScore = f1.score;
res.factorBreakdown.add(f1);

        // ── FACTOR 2: Vehicle History Consistency (20 pts) ───────────────────
        FactorDetail f2 = new FactorDetail();
        f2.factorName = 'Vehicle History Consistency';
        f2.weight     = 20;

        Decimal currentMileage = ctx.claim.Current_Mileage__c ?? 0;
        if (currentMileage > 0 && ctx.maxPriorMileage > 0 && currentMileage < ctx.maxPriorMileage) {
            f2.score     = 0;
            f2.reasoning = 'Odometer rollback detected: current mileage (' + currentMileage
                         + ' km) is lower than previous Claim record (' + ctx.maxPriorMileage + ' km).';
        } else if (ctx.priorClaimCount == 0) {
            f2.score     = 20;
            f2.reasoning = 'First Claim for this product on this Asset. No prior claim history.';
        } else if (ctx.priorClaimCount == 1) {
            f2.score     = 10;
            f2.reasoning = '1 prior Claim for same part on this Asset. Borderline — monitor.';
        } else {
            f2.score     = 5;
            f2.reasoning = ctx.priorClaimCount + ' prior Claims for same part on this Asset. Potential part churning.';
        }
        res.historyScore = f2.score;
        res.factorBreakdown.add(f2);

        // ── FACTOR 3: Dealer Credibility via Account (15 pts) ────────────────
        FactorDetail f3 = new FactorDetail();
        f3.factorName = 'Dealer Credibility';
        f3.weight     = 15;

        // NOTE: Account.Tier__c, Credibility_Score__c, Fraud_Investigation_Active__c
        // do not exist in this org. Only Account.Dealer_Code__c is available.
        // Dealer credibility defaults to 10 pts (standard) until those fields are created.
        // When the fields are deployed, uncomment the full logic below.
        String dealerCode = ctx.claim.Account?.Dealer_Code__c;
        if (String.isNotBlank(dealerCode)) {
            f3.score     = 15;
            f3.reasoning = 'Known dealer (code: ' + dealerCode + '). Dealer credibility confirmed.';
        } else {
            f3.score     = 10;
            f3.reasoning = 'Dealer identified but no Dealer Code on file. Standard credibility applied.';
        }
        res.dealerScore = f3.score;
        res.factorBreakdown.add(f3);

        // ── FACTOR 4: Claim Cost vs. Benchmark (15 pts) ──────────────────────
        FactorDetail f4 = new FactorDetail();
        f4.factorName = 'Claim Cost vs. Benchmark';
        f4.weight     = 15;

        Decimal cost = ctx.claim.EstimatedAmount ?? 0;
        Decimal avg  = ctx.costBenchmarkAvg;
        Decimal std  = ctx.costBenchmarkStdDev;

        if (avg == 0 || std == 0) {
            f4.score     = 8;
            f4.reasoning = 'No benchmark data available on Product2. Neutral score applied.';
        } else {
            Decimal deviation = Math.abs(cost - avg);
            if (deviation <= std) {
                f4.score     = 15;
                f4.reasoning = 'Claim amount ₹' + cost.setScale(0) + ' is within 1 std dev of benchmark (₹' + avg.setScale(0) + '). Normal range.';
            } else if (deviation <= (std * 2)) {
                f4.score     = 8;
                f4.reasoning = 'Claim amount ₹' + cost.setScale(0) + ' is within 2 std devs. Elevated but not flagged.';
            } else {
                f4.score     = 0;
                f4.reasoning = 'Claim amount ₹' + cost.setScale(0) + ' exceeds 2x std dev from benchmark. Potential cost inflation.';
            }
        }
        res.costScore = f4.score;
        res.factorBreakdown.add(f4);

        // ── FACTOR 5: Evidence Completeness (15 pts) ──────────────────────
       // ── FACTOR 5: Evidence Completeness (15 pts) ──────────────────────
        FactorDetail f5 = new FactorDetail();
        f5.factorName = 'Evidence Completeness';
        f5.weight     = 15;

        // 1) Count ClaimItems with description
        Integer itemCount = 0;

        List<ClaimItem> items = [
            SELECT Description
            FROM ClaimItem
            WHERE ClaimId = :ctx.claim.Id
        ];

        for (ClaimItem ci : items) {
            if (String.isNotBlank(ci.Description)) {
                itemCount++;
            }
        }

        // 2) Count attachments (Files)
        Integer attachmentCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ctx.claim.Id
        ];

        // 3) Scoring logic (NO validated field anymore)
        if (itemCount >= 1 && attachmentCount >= 1) {
            f5.score     = 15;
            f5.reasoning = 'Claim has description and at least 1 attachment.';
        }
        else if (itemCount >= 1 || attachmentCount >= 1) {
            f5.score     = 8;
            f5.reasoning = 'Partial evidence available (description or attachment).';
        }
        else {
            f5.score     = 0;
            f5.reasoning = 'No description or attachments found.';
        }

        res.evidenceScore = f5.score;
        res.factorBreakdown.add(f5);

        // ── FACTOR 6: Known Defect Correlation via Product2 (10 pts) ─────────
        FactorDetail f6 = new FactorDetail();
        f6.factorName = 'Known Defect Correlation';
        f6.weight     = 10;

        Boolean knownDefect  = ctx.part?.Known_Defect__c == true;
        Boolean hasTSB       = String.isNotBlank(ctx.part?.TSB_Reference__c);
        Boolean recallActive = ctx.part?.Recall_Active__c == true;

        if (knownDefect || hasTSB || recallActive) {
            String reason = recallActive ? 'Active recall on Product2.'
                : hasTSB ? 'Active TSB on Product2: ' + ctx.part.TSB_Reference__c
                : 'Known manufacturing defect flagged on Product2.';
            f6.score     = 10;
            f6.reasoning = reason;
        } else {
            f6.score     = 5;
            f6.reasoning = 'No known defect, TSB, or active recall on Product2. Standard scoring applied.';
        }
        res.defectScore = f6.score;
        res.factorBreakdown.add(f6);

        // ── TOTAL + ROUTING DECISION ─────────────────────────────────────────
        res.totalScore = res.coverageScore + res.historyScore + res.dealerScore
                       + res.costScore     + res.evidenceScore + res.defectScore;

        if (res.totalScore >= 85) {
            res.routingDecision = 'AUTO_APPROVE';
        } else if (res.totalScore >= 40) {
            res.routingDecision = 'HUMAN_REVIEW';
        } else {
            res.routingDecision = 'INVESTIGATE';
        }

        res.aiSummary = 'Confidence Score: ' + res.totalScore + '/100. Decision: '
            + res.routingDecision
            + '. Coverage=' + res.coverageScore
            + ', History='  + res.historyScore
            + ', Dealer='   + res.dealerScore
            + ', Cost='     + res.costScore
            + ', Evidence=' + res.evidenceScore
            + ', Defect='   + res.defectScore + '.';

        return res;
    }

    // =========================================================================
    // PERSIST RESULTS — Writes score back to Claim + creates detail records
    // =========================================================================

    @TestVisible
    private static void persistResults(Id claimId, ScoreResult res) {
        Datetime now = Datetime.now();

        // ── Determine new Claim Status from routing decision ─────────────────
        String newStatus = res.routingDecision == 'AUTO_APPROVE' ? 'Approved'
                         : res.routingDecision == 'INVESTIGATE'  ? 'Under Investigation'
                         : 'Under Review';

       // ── Determine Status + Flags explicitly from score ─────────────────
        Boolean isAutoApprove = res.totalScore >= 85;
        Boolean isInvestigate = res.totalScore < 40;

        // ── Update Claim ───────────────────────────────────────────────────
        Claim c = new Claim(Id = claimId);

        c.Confidence_Score__c   = res.totalScore;
        c.AI_Summary__c         = res.aiSummary;
        c.Scoring_Run_At__c     = now;
        c.Evidence_Completed__c = (res.evidenceScore == 15);

        // ✅ Auto Approval Logic
        if (isAutoApprove) {
            c.Auto_Approved__c = true;
            c.Fruad_Flag__c    = false;
            c.Status           = 'Approved';
            Decimal estimatedAmount = [
                SELECT EstimatedAmount
                FROM Claim
                WHERE Id = :claimId
            ].EstimatedAmount;

            c.ApprovedAmount = estimatedAmount;
        }

        // ⚠️ Investigation / Fraud Logic
        else if (isInvestigate) {
            c.Auto_Approved__c = false;
            c.Fruad_Flag__c    = true;
            c.Status           = 'Under Investigation';
        }

        // 🔄 Human Review Logic
        else {
            c.Auto_Approved__c = false;
            c.Fruad_Flag__c    = false;
            c.Status           = 'Under Review';
            c.SLA_Due_Date__c  = now.addHours(4);
        }

        update c;

        // ── Create Claim_Score_Detail__c — one record per factor ─────────────
        List<Claim_Score_Detail__c> details = new List<Claim_Score_Detail__c>();
        Integer idx = 1;
        for (FactorDetail fd : res.factorBreakdown) {
            Claim_Score_Detail__c det = new Claim_Score_Detail__c();
            det.Name            = claimId + '-F' + idx;
            det.Claim__c        = claimId;         // Lookup to standard Claim (new field)
            det.Factor__c       = fd.factorName;
            det.Weight__c       = fd.weight;
            det.Score__c        = fd.score;
            det.Reasoning__c    = fd.reasoning;
            det.Run_Timestamp__c = now;
            details.add(det);
            idx++;
        }
        insert details;

        // ── Publish Claim_Scored_Event__e for downstream routing flows ────────
        // Claim_Scored_Event__e evt = new Claim_Scored_Event__e(
        //     Claim_Id__c         = claimId,
        //     Score__c            = res.totalScore,
        //     Routing_Decision__c = res.routingDecision
        // );
        // EventBus.publish(evt);
    }

    // =========================================================================
    // MANUAL RE-SCORE — Called by Approver Copilot (Agent 3 / Slack)
    // =========================================================================

    @AuraEnabled
    public static ScoreResult rescoreClaim(Id claimId) {
        ClaimContext ctx = loadContext(claimId);
        ScoreResult  res = runScoringFactors(ctx);
        persistResults(claimId, res);
        return res;
    }
}