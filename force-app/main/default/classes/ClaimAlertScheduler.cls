/**
 * ClaimAlertScheduler
 * ─────────────────────────────────────────────────────────────────────────────
 * Schedulable class — wires ClaimAlertQueryService + ClaimAlertFormatter
 * together and fires SlackAlertService.sendMessage().
 *
 * TO SCHEDULE FROM ANONYMOUS WINDOW:
 *   // Every day at 9:00 AM IST (3:30 AM UTC)
 *   String cronExpr = '0 30 3 * * ?';
 *   System.schedule('Daily Claim Slack Alert', cronExpr, new ClaimAlertScheduler());
 *
 * TO SCHEDULE FROM SETUP UI:
 *   Setup → Apex Classes → Schedule Apex → pick ClaimAlertScheduler
 *
 * TO CANCEL:
 *   List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Daily Claim Slack Alert'];
 *   System.abortJob(jobs[0].Id);
 * ─────────────────────────────────────────────────────────────────────────────
 */
global class ClaimAlertScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        try {
            

            // Step 3 — Send to Slack (@future call — must be called from non-future context)
            SlackAlertService.sendMessage();

        } catch (Exception ex) {
            System.debug('ClaimAlertScheduler error: ' + ex.getMessage());
        }
    }
}