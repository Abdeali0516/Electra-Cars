/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : WarrantyProfile
 * Author          : <YourName>
 * Created Date    : Apr 22, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Apr 22, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 22, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
 @JsonAccess(serializable='always' deserializable='always')
global class WarrantyProfile {
    @AuraEnabled public String  vin;
    @AuraEnabled public String  vehicleId;
    @AuraEnabled public String  vehicleName;
    @AuraEnabled public String  chassisNumber;
    @AuraEnabled public String  stockCode;
    @AuraEnabled public String  vehicleStatus;
    @AuraEnabled public String  engineNumber;
    @AuraEnabled public String  exteriorColor;
    @AuraEnabled public String  interiorColor;
    @AuraEnabled public String  gearBoxType;
    @AuraEnabled public String  manufacturedDate;
    @AuraEnabled public String  lastServiceDate;
    @AuraEnabled public String  warrantyStatus;
    @AuraEnabled public String  warrantyStart;
    @AuraEnabled public String  warrantyEnd;
    @AuraEnabled public Integer activeContracts;
    @AuraEnabled public Integer activeWarranty;
    @AuraEnabled public String  ownerName;
    @AuraEnabled public String  ownerEmail;
    @AuraEnabled public String  ownerPhone;
    @AuraEnabled public String  ownerCity;
    @AuraEnabled public String  ownerState;
    @AuraEnabled public String  dealerName;
    @AuraEnabled public Integer claimCount;
    @AuraEnabled public String  claimId;
    @AuraEnabled public Decimal reportedMileage;
    @AuraEnabled public List<WarrantyItem> warranties;

    @JsonAccess(serializable='always' deserializable='always')
    global class WarrantyItem {
        @AuraEnabled public String  warrantyType;
        @AuraEnabled public String  endDate;
        @AuraEnabled public Decimal mileageLimit;
    }
}