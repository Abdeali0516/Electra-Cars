public class AccountAgentHandler {

    public static void notifyAgent(List<Account> accounts) {
        List<AgentNotifier.Input> inputs = new List<AgentNotifier.Input>();

        for (Account acc : accounts) {
            AgentNotifier.Input inp = new AgentNotifier.Input();
            inp.accountName = acc.Name;
            inp.accountId = acc.Id;
            inputs.add(inp);
        }

        // Call Invocable method
        AgentNotifier.notify(inputs);
    }
}