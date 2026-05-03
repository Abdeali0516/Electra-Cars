/**
 * DealerDashboardController
 * Apex controller for the Electra Dealer Portal Home Dashboard LWC.
 *
 * Security: `with sharing` enforces record-level sharing rules, ensuring a
 * dealer user can only read records their profile is permitted to see.
 * All queries are additionally filtered by the logged-in user's AccountId so
 * one dealer can never see another dealer's data.
 */
public with sharing class DealerDashboardController {

    // ─────────────────────────────────────────────────────────────────────────
    // Main entry point — called via @wire from the LWC
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        Id dealerAccountId = resolveDealerAccountId();

        DashboardData data = new DashboardData();
        data.dealerAccountId = String.valueOf(dealerAccountId);

        // Dealer account details
        Account acct = [
            SELECT Id, Name, Phone, BillingCity, BillingState
            FROM   Account
            WHERE  Id = :dealerAccountId
            LIMIT  1
        ];
        data.dealerName  = acct.Name;
        data.dealerPhone = acct.Phone;
        data.dealerCity  = acct.BillingCity;
        data.dealerState = acct.BillingState;

        // ── Vehicles ──────────────────────────────────────────────────────────
        List<Vehicle> rawVehicles = [
            SELECT Id, Name, VehicleIdentificationNumber, Status, ExteriorColor,
                   ManufacturerWarrantyStartDt, ManufacturerWarrantyEndDate,
                   ManufacturedDate, LastServiceDate,
                   ActiveWarrantyCount, ActiveServiceContractCount
            FROM   Vehicle
            WHERE  CurrentOwnerId = :dealerAccountId
            ORDER BY Name ASC
            LIMIT  200
        ];

        Integer activeWarrantyCount = 0;
        data.vehicles = new List<VehicleRow>();
        for (Vehicle v : rawVehicles) {
            VehicleRow row      = new VehicleRow();
            row.vehicleId       = v.Id;
            row.name            = v.Name;
            row.vin             = v.VehicleIdentificationNumber;
            row.status          = v.Status;
            row.color           = v.ExteriorColor;
            row.manufacturedDate = v.ManufacturedDate  != null ? String.valueOf(v.ManufacturedDate)  : '—';
            row.lastServiceDate  = v.LastServiceDate   != null ? String.valueOf(v.LastServiceDate)   : '—';
            row.warrantyStart    = v.ManufacturerWarrantyStartDt  != null ? String.valueOf(v.ManufacturerWarrantyStartDt)  : '—';
            row.warrantyEnd      = v.ManufacturerWarrantyEndDate  != null ? String.valueOf(v.ManufacturerWarrantyEndDate)  : '—';
            row.activeWarrantyCount = v.ActiveWarrantyCount != null ? Integer.valueOf(v.ActiveWarrantyCount) : 0;
            row.warrantyStatus   = resolveWarrantyStatus(v);
            row.warrantyBadgeClass = warrantyBadgeCss(row.warrantyStatus);
            if (row.warrantyStatus == 'Active') activeWarrantyCount++;
            data.vehicles.add(row);
        }

        // ── Claims ────────────────────────────────────────────────────────────
        List<Claim> rawClaims = [
            SELECT Id, Name, Status, ClaimType, InitiationDate,
                   ClaimReason, Summary, IsDrivable
            FROM   Claim
            WHERE  AccountId = :dealerAccountId
            ORDER BY InitiationDate DESC NULLS LAST
            LIMIT  100
        ];

        Integer openClaimsCount = 0;
        List<Id> claimIds = new List<Id>();
        data.claims = new List<ClaimRow>();
        for (Claim c : rawClaims) {
            ClaimRow row       = new ClaimRow();
            row.claimId        = c.Id;
            row.name           = c.Name;
            row.status         = c.Status    != null ? c.Status    : '—';
            row.claimType      = c.ClaimType != null ? c.ClaimType : '—';
            row.initiationDate = c.InitiationDate != null ? String.valueOf(c.InitiationDate) : '—';
            row.reason         = c.ClaimReason != null ? c.ClaimReason : '—';
            row.summary        = c.Summary    != null ? c.Summary    : '—';
            row.isDrivable     = c.IsDrivable;
            row.statusBadgeClass = statusBadgeCss(c.Status);
            if (c.Status == null || c.Status != 'Closed') openClaimsCount++;
            claimIds.add(c.Id);
            data.claims.add(row);
        }

        // ── Claim Items ───────────────────────────────────────────────────────
        data.claimItems = new List<ClaimItemRow>();
        if (!claimIds.isEmpty()) {
            List<ClaimItem> rawItems = [
                SELECT Id, Name, ClaimId
                FROM   ClaimItem
                WHERE  ClaimId IN :claimIds
                ORDER BY CreatedDate DESC
                LIMIT  200
            ];
            for (ClaimItem ci : rawItems) {
                ClaimItemRow row = new ClaimItemRow();
                row.itemId       = ci.Id;
                row.name         = ci.Name;
                row.claimId      = ci.ClaimId;
                data.claimItems.add(row);
            }
        }

        // ── KPI counters ──────────────────────────────────────────────────────
        data.totalVehicles    = rawVehicles.size();
        data.activeWarranties = activeWarrantyCount;
        data.openClaims       = openClaimsCount;
        data.totalClaims      = rawClaims.size();
        data.totalClaimItems  = data.claimItems.size();

        return data;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static Id resolveDealerAccountId() {
        List<User> users = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (users.isEmpty() || users[0].AccountId == null) {
            throw new AuraHandledException(
                'No dealer account is linked to your user profile. Please contact your administrator.'
            );
        }
        return users[0].AccountId;
    }

    private static String resolveWarrantyStatus(Vehicle v) {
        if (v.ManufacturerWarrantyEndDate != null) {
            return v.ManufacturerWarrantyEndDate >= Date.today() ? 'Active' : 'Expired';
        }
        if (v.ActiveWarrantyCount != null && v.ActiveWarrantyCount > 0) return 'Active';
        if (v.ActiveServiceContractCount != null && v.ActiveServiceContractCount > 0) return 'Contract';
        return 'None';
    }

    private static String statusBadgeCss(String status) {
        if (status == null) return 'dd-badge dd-badge-neutral';
        String s = status.toLowerCase();
        if (s == 'draft' || s == 'new' || s == 'open')                        return 'dd-badge dd-badge-open';
        if (s == 'in progress' || s == 'under review' || s == 'processing')   return 'dd-badge dd-badge-progress';
        if (s == 'closed' || s == 'approved' || s == 'settled')               return 'dd-badge dd-badge-closed';
        if (s == 'rejected' || s == 'denied')                                  return 'dd-badge dd-badge-rejected';
        return 'dd-badge dd-badge-neutral';
    }

    private static String warrantyBadgeCss(String ws) {
        if (ws == 'Active')   return 'dd-badge dd-badge-active';
        if (ws == 'Expired')  return 'dd-badge dd-badge-expired';
        if (ws == 'Contract') return 'dd-badge dd-badge-contract';
        return 'dd-badge dd-badge-neutral';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Wrapper classes — only expose fields needed by the LWC
    // ─────────────────────────────────────────────────────────────────────────

    public class DashboardData {
        @AuraEnabled public String  dealerAccountId;
        @AuraEnabled public String  dealerName;
        @AuraEnabled public String  dealerPhone;
        @AuraEnabled public String  dealerCity;
        @AuraEnabled public String  dealerState;
        @AuraEnabled public Integer totalVehicles;
        @AuraEnabled public Integer activeWarranties;
        @AuraEnabled public Integer openClaims;
        @AuraEnabled public Integer totalClaims;
        @AuraEnabled public Integer totalClaimItems;
        @AuraEnabled public List<VehicleRow>   vehicles;
        @AuraEnabled public List<ClaimRow>     claims;
        @AuraEnabled public List<ClaimItemRow> claimItems;
    }

    public class VehicleRow {
        @AuraEnabled public String  vehicleId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  vin;
        @AuraEnabled public String  status;
        @AuraEnabled public String  color;
        @AuraEnabled public String  manufacturedDate;
        @AuraEnabled public String  lastServiceDate;
        @AuraEnabled public String  warrantyStart;
        @AuraEnabled public String  warrantyEnd;
        @AuraEnabled public Integer activeWarrantyCount;
        @AuraEnabled public String  warrantyStatus;
        @AuraEnabled public String  warrantyBadgeClass;
    }

    public class ClaimRow {
        @AuraEnabled public String  claimId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public String  claimType;
        @AuraEnabled public String  initiationDate;
        @AuraEnabled public String  reason;
        @AuraEnabled public String  summary;
        @AuraEnabled public Boolean isDrivable;
        @AuraEnabled public String  statusBadgeClass;
    }

    public class ClaimItemRow {
        @AuraEnabled public String itemId;
        @AuraEnabled public String name;
        @AuraEnabled public String claimId;
    }
}