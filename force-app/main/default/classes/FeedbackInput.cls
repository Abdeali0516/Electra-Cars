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