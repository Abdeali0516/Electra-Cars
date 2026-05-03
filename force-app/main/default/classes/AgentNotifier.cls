public class AgentNotifier {

    public class Input {
        @InvocableVariable(required=true)
        public String accountName;

        @InvocableVariable(required=true)
        public Id accountId;
    }

    @InvocableMethod(label='Notify Agent on Account Creation')
    public static void notify(List<Input> inputs) {

        for (Input inp : inputs) {
            System.debug('Agent Notification Triggered for Account: ' + inp.accountName);

            // Simulate Agentforce action
            // Replace this with actual Agentforce call / Platform Event / Flow trigger
        }
    }
}