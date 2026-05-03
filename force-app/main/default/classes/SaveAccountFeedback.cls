global class SaveAccountFeedback {

    @InvocableMethod(label='Save Account Feedback'
                     description='Saves how are they today response to Account Description')
    global static List<Response> save(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            try {
                String textToSave = req.feedback != null
                    ? req.feedback.combinedFeedback
                    : '';
                Account acc = new Account(
                    Id          = req.accountId,
                    Description = textToSave
                );
                update acc;
                Response r  = new Response();
                r.isSuccess = true;
                r.message   = 'Feedback saved successfully.';
                responses.add(r);
            } catch (Exception e) {
                Response r  = new Response();
                r.isSuccess = false;
                r.message   = e.getMessage();
                responses.add(r);
            }
        }
        return responses;
    }

    @JsonAccess(serializable='always' deserializable='always')
    global class Request {
        @InvocableVariable(label='Account ID' required=true)
        global String accountId;

        @InvocableVariable(label='Feedback' required=true)
        global FeedbackInput feedback;      // ← complex type, not String
    }

    @JsonAccess(serializable='always' deserializable='always')
    global class FeedbackInput {
        @AuraEnabled
        global String selectedMood;

        @AuraEnabled
        global String feedbackText;

        @AuraEnabled
        global String combinedFeedback;

        @AuraEnabled
        global String submitRequested;
    }

    @JsonAccess(serializable='always' deserializable='always')
    global class Response {
        @InvocableVariable
        global Boolean isSuccess;

        @InvocableVariable
        global String message;
    }
}