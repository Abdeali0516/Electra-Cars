public with sharing class ClaimApprovalService {

    public class Request {
        @InvocableVariable(required=true)
        public List<String> claimNumbers;

        @InvocableVariable
        public Decimal approvedAmount; // required only for approve

        @InvocableVariable(required=true)
        public String action; // approve / reject
    }

    public class Response {
        @InvocableVariable
        public List<String> processedClaims;

        @InvocableVariable
        public Integer count;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Approve or Reject Claims by Claim Number')
    public static List<Response> processClaims(List<Request> requests) {

        Request req = requests[0];

        if (req.claimNumbers == null || req.claimNumbers.isEmpty()) {
            throw new AuraHandledException('Claim numbers are required');
        }

        if (String.isBlank(req.action)) {
            throw new AuraHandledException('Action is required (approve/reject)');
        }

        String action = req.action.toLowerCase();

        // Validate amount only for approve
        if (action == 'approve' && req.approvedAmount == null) {
            throw new AuraHandledException('Approved amount is required for approval');
        }

        List<Claim> claimsToUpdate = [
            SELECT Id, Name, Status, ApprovedAmount
            FROM Claim
            WHERE Name IN :req.claimNumbers
        ];

        if (claimsToUpdate.isEmpty()) {
            throw new AuraHandledException('No matching claims found');
        }

        List<String> processedNames = new List<String>();

        for (Claim c : claimsToUpdate) {

            if (action == 'approve') {
                if (c.Status != 'Approved') {
                    c.Status = 'Approved';
                    c.ApprovedAmount = req.approvedAmount;
                    processedNames.add(c.Name);
                }
            }

            else if (action == 'reject') {
                if (c.Status != 'Rejected') {
                    c.Status = 'Rejected';
                    c.ApprovedAmount = null; // optional reset
                    processedNames.add(c.Name);
                }
            }

            else {
                throw new AuraHandledException('Invalid action. Use approve or reject');
            }
        }

        update claimsToUpdate;

        // Build response
        Response res = new Response();
        res.processedClaims = processedNames;
        res.count = processedNames.size();
        res.message = res.count + ' claim(s) ' + action + 'd successfully.';

        return new List<Response>{ res };
    }
}