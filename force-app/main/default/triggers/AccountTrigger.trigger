trigger AccountTrigger on Account (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        AccountAgentHandler.notifyAgent(Trigger.new);
    }
}