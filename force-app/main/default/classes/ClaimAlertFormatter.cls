/**
 * ClaimAlertFormatter
 * ─────────────────────────────────────────────────────────────────────────────
 * Builds the Slack message string from a ClaimCounts object.
 * Kept separate from the query and scheduler so the message format
 * can be changed without touching any scheduling or DML logic.
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class ClaimAlertFormatter {

    /**
     * Returns a formatted Slack message string.
     * Uses Slack's mrkdwn syntax — bold = *text*, code = `text`.
     */
    public static String buildMessage(ClaimAlertQueryService.ClaimCounts counts) {

    String formattedTime = counts.asOf.format('dd MMM yyyy, hh:mm a', 'Asia/Kolkata');

    String msg = '*Electra Warranty — Pending Claims Alert*\n';
    msg += formattedTime + ' IST\n\n';

    msg += '*Total Pending Claims:* ' + counts.totalPending + '\n\n';

    msg += '*Breakdown by Priority:*\n';
    msg += '🟢 Low Risk (Auto-Approval): ' + counts.scenario1Count + '\n';
    msg += '🟠 Medium Risk (Needs Review): ' + counts.scenario2Count + '\n';
    msg += '🔴 High Risk (Needs Investigation): ' + counts.scenario3Count + '\n';

    if (counts.scenario3Count >= 5) {
        msg += '\n🚨 *' + counts.scenario3Count + ' high-risk claims require immediate attention.*\n';
    }

    return msg;
}
}