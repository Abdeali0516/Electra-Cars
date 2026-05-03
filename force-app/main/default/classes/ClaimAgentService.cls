public with sharing class ClaimAgentService {

    // ================= REQUEST / RESPONSE =================

    public class Request {
        @InvocableVariable(required=true)
        public String timeFilter; // today, yesterday, thisMonth, lastMonth

        @InvocableVariable
        public String statusFilter; // pending, approved, rejected

        @InvocableVariable
        public Integer limitSize; // optional (max capped)
    }

    public class Response {
        @InvocableVariable
        public List<Claim> claims;

        @InvocableVariable
        public Integer count;

        @InvocableVariable
        public String message;
    }

    // ================= MAIN METHOD =================

    @InvocableMethod(label='Get Claims by Time & Status')
    public static List<Response> getClaims(List<Request> requests) {

        Request req = requests[0];

        if (String.isBlank(req.timeFilter)) {
            throw new AuraHandledException('Time filter is required');
        }

        String filter = req.timeFilter.toLowerCase().replace(' ', '');
        String dateLiteral;

        // Date mapping
        if (filter == 'today') {
            dateLiteral = 'TODAY';
        } else if (filter == 'yesterday') {
            dateLiteral = 'YESTERDAY';
        } else if (filter == 'thismonth') {
            dateLiteral = 'THIS_MONTH';
        } else if (filter == 'lastmonth') {
            dateLiteral = 'LAST_MONTH';
        } else {
            throw new AuraHandledException(
                'Invalid time filter. Use: today, yesterday, thisMonth, lastMonth'
            );
        }

        // Default + max limit protection
        Integer limitSize = (req.limitSize == null) ? 10 : req.limitSize;
        if (limitSize > 50) limitSize = 50;

        // Base query
        String query = 'SELECT Id, Name, Status, EstimatedAmount ' +
                       'FROM Claim ' +
                       'WHERE CreatedDate = ' + dateLiteral;

        // Status filter (optional)
        if (!String.isBlank(req.statusFilter)) {

            String status = req.statusFilter.toLowerCase();

            if (status == 'pending') {
                query += ' AND Status IN (\'Draft\', \'Under Review\')';
            } 
            else if (status == 'approved') {
                query += ' AND Status = \'Approved\'';
            } 
            else if (status == 'rejected') {
                query += ' AND Status = \'Rejected\'';
            } 
            else {
                throw new AuraHandledException(
                    'Invalid status. Use: pending, approved, rejected'
                );
            }
        }

        // Oldest first + limit
        query += ' ORDER BY CreatedDate ASC LIMIT ' + limitSize;

        List<Claim> claims = Database.query(query);

        // Build response
        Response res = new Response();
        res.claims = claims;
        res.count = claims.size();
        res.message = res.count + ' claim(s) retrieved';

        return new List<Response>{ res };
    }
}