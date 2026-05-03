/**
 * ClaimApprovalNotifier
 * ─────────────────────────────────────────────────────────────────────────────
 * Sends a customer-facing approval email when a Claim's Status becomes 'Approved'.
 * Called from ClaimTrigger BEFORE the reentrancy guard so it fires on both:
 *   - Direct DML that sets Status = 'Approved'
 *   - ClaimScoringEngine auto-approval (internal update)
 *
 * Recipient: primary Contact (by CreatedDate) on the Claim's Account that has
 *            a non-null Email address.
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class ClaimApprovalNotifier {

    // ── Entry point from trigger ──────────────────────────────────────────────

    public static void sendApprovalEmails(List<Id> claimIds) {
        System.debug('ClaimApprovalNotifier.sendApprovalEmails called with claimIds=' + claimIds);
        if (claimIds == null || claimIds.isEmpty()) {
            System.debug('ClaimApprovalNotifier: claimIds is null or empty — returning early');
            return;
        }

        if (System.isFuture() || System.isBatch()) {
            System.debug('ClaimApprovalNotifier: already in async context (isFuture=' + System.isFuture() + ', isBatch=' + System.isBatch() + ') — calling sendEmailsDirect inline');
            sendEmailsDirect(claimIds);
        } else {
            System.debug('ClaimApprovalNotifier: dispatching to @future method');
            sendEmailsAsync(claimIds);
        }
    }

    @future
    private static void sendEmailsAsync(List<Id> claimIds) {
        System.debug('ClaimApprovalNotifier.sendEmailsAsync (@future) executing with claimIds=' + claimIds);
        sendEmailsDirect(claimIds);
    }

    // ── Core logic ────────────────────────────────────────────────────────────

    @TestVisible
    private static void sendEmailsDirect(List<Id> claimIds) {
        System.debug('ClaimApprovalNotifier.sendEmailsDirect entered. claimIds=' + claimIds);

        List<Claim> claims = [
            SELECT Id, Name, Status, ClaimType, ClaimReason, Severity,
                   EstimatedAmount,ApprovedAmount, CurrencyIsoCode,
                   InitiationDate, AssessmentDate, FinalizedDate,
                    TotalClaimedAmount,
                   Confidence_Score__c, Auto_Approved__c, AI_Summary__c,
                   AccountId, Account.Name,
                   InsuredAssetId, InsuredAsset.Name
            FROM Claim
            WHERE Id IN :claimIds
        ];

        System.debug('ClaimApprovalNotifier: queried ' + claims.size() + ' Claim record(s)');
        if (claims.isEmpty()) {
            System.debug('ClaimApprovalNotifier: no Claim records found — returning early');
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Claim c : claims) {
            System.debug('ClaimApprovalNotifier: Claim Id=' + c.Id + ' Name=' + c.Name + ' Status=' + c.Status + ' AccountId=' + c.AccountId);
            if (c.AccountId != null) accountIds.add(c.AccountId);
        }
        System.debug('ClaimApprovalNotifier: accountIds to look up Contacts for=' + accountIds);

        Map<Id, Contact> primaryContact = new Map<Id, Contact>();
        List<Contact> allContacts = [
            SELECT Id, AccountId, FirstName, LastName, Email
            FROM   Contact
            WHERE  AccountId IN :accountIds
              AND  Email     != null
            ORDER BY CreatedDate ASC
        ];
        System.debug('ClaimApprovalNotifier: found ' + allContacts.size() + ' Contact(s) with email across all accounts');
        for (Contact con : allContacts) {
            System.debug('ClaimApprovalNotifier: Contact Id=' + con.Id + ' AccountId=' + con.AccountId + ' Email=' + con.Email);
            if (!primaryContact.containsKey(con.AccountId)) {
                primaryContact.put(con.AccountId, con);
                System.debug('ClaimApprovalNotifier: assigned primary Contact ' + con.Id + ' (' + con.Email + ') for AccountId=' + con.AccountId);
            }
        }

        // Resolve org-wide email address for the FROM field
        Id oweaId = null;
        List<OrgWideEmailAddress> oweas = [
            SELECT Id, Address FROM OrgWideEmailAddress
            WHERE Address = 'vivek.devmurari1214@gmail.com'
            LIMIT 1
        ];
        System.debug('ClaimApprovalNotifier: OrgWideEmailAddress query returned ' + oweas.size() + ' record(s)');
        if (!oweas.isEmpty()) {
            oweaId = oweas[0].Id;
            System.debug('ClaimApprovalNotifier: using OrgWideEmailAddress Id=' + oweaId + ' address=' + oweas[0].Address);
        } else {
            System.debug('ClaimApprovalNotifier: WARNING — OrgWideEmailAddress for vivek.devmurari1214@gmail.com not found; email will send from running user');
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Claim c : claims) {
            Contact con = primaryContact.get(c.AccountId);
            if (con == null) {
                System.debug('ClaimApprovalNotifier: SKIP Claim ' + c.Id + ' — no Contact with email found for AccountId=' + c.AccountId);
                continue;
            }
            if (String.isBlank(con.Email)) {
                System.debug('ClaimApprovalNotifier: SKIP Claim ' + c.Id + ' — Contact ' + con.Id + ' has blank email');
                continue;
            }

            System.debug('ClaimApprovalNotifier: building email for Claim ' + c.Id + ' → recipient=' + con.Email);
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ con.Email });
            msg.setSubject('Your Warranty Claim ' + c.Name + ' Has Been Approved');
            msg.setHtmlBody(buildEmailHtml(c, con));
            msg.setSaveAsActivity(false);
            if (oweaId != null) {
                msg.setOrgWideEmailAddressId(oweaId);
                System.debug('ClaimApprovalNotifier: FROM set via OrgWideEmailAddress');
            }
            emails.add(msg);
            System.debug('ClaimApprovalNotifier: email queued for Claim ' + c.Id + ' to ' + con.Email);
        }

        System.debug('ClaimApprovalNotifier: total emails to send=' + emails.size());
        if (!emails.isEmpty()) {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false);
            for (Integer i = 0; i < results.size(); i++) {
                Messaging.SendEmailResult r = results[i];
                if (r.isSuccess()) {
                    System.debug('ClaimApprovalNotifier: email[' + i + '] SENT successfully to ' + emails[i].getToAddresses());
                } else {
                    for (Messaging.SendEmailError err : r.getErrors()) {
                        System.debug('ClaimApprovalNotifier: email[' + i + '] FAILED — statusCode=' + err.getStatusCode() + ' message=' + err.getMessage() + ' targetObjectId=' + err.getTargetObjectId());
                    }
                }
            }
        } else {
            System.debug('ClaimApprovalNotifier: no emails built — sendEmail not called');
        }
    }

    // ── HTML Email Builder ────────────────────────────────────────────────────

    private static String buildEmailHtml(Claim c, Contact con) {
        String greeting    = String.isNotBlank(con.FirstName) ? con.FirstName : (con.LastName != null ? con.LastName : 'Valued Customer');
        String currCode    = String.isNotBlank(c.CurrencyIsoCode) ? c.CurrencyIsoCode : 'USD';
        String estimatedAmt= c.EstimatedAmount != null ? fmtCurrency(c.EstimatedAmount, currCode) : '—';
        String score       = c.Confidence_Score__c != null ? String.valueOf(c.Confidence_Score__c.intValue()) + ' / 100' : '—';
        String initDate    = c.InitiationDate  != null ? c.InitiationDate.format()  : '—';
        String claimType   = String.isNotBlank(c.ClaimType)    ? c.ClaimType    : '—';
        String severity    = String.isNotBlank(c.Severity)     ? c.Severity     : '—';
        String claimReason = String.isNotBlank(c.ClaimReason)  ? c.ClaimReason  : '—';
        String processingMethod = c.Auto_Approved__c == true
            ? 'Auto-Approved by AI Engine'
            : 'Approved by Review Team';
        String currentYear = String.valueOf(Datetime.now().year());
        String approvedAmt = c.ApprovedAmount != null 
    ? fmtCurrency(c.ApprovedAmount, currCode) 
    : '—';

        return
        '<!DOCTYPE html><html lang="en">' +
        '<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>' +
        '<body style="margin:0;padding:0;background-color:#f0f4f8;font-family:\'Segoe UI\',Helvetica,Arial,sans-serif;">' +

        // ── Outer wrapper ──────────────────────────────────────────────────────
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"' +
        ' style="background-color:#f0f4f8;padding:40px 16px;">' +
        '<tr><td align="center">' +
        '<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"' +
        ' style="max-width:600px;width:100%;border-radius:16px;overflow:hidden;' +
        '        box-shadow:0 8px 32px rgba(0,0,0,0.12);">' +

        // ── Header ────────────────────────────────────────────────────────────
        '<tr><td style="background:linear-gradient(135deg,#0E1E35 0%,#1a3a60 100%);padding:36px 40px 28px;">' +
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>' +
        '<td style="vertical-align:middle;">' +
        '<p style="margin:0;font-size:10px;font-weight:700;color:#00C8E8;letter-spacing:2.5px;text-transform:uppercase;">Electra Warranty Intelligence</p>' +
        '<h1 style="margin:8px 0 0;font-size:28px;font-weight:800;color:#ffffff;line-height:1.2;letter-spacing:-0.5px;">Claim Approved</h1>' +
        '</td>' +
        '<td style="vertical-align:middle;text-align:right;padding-left:16px;white-space:nowrap;">' +
        '<span style="display:inline-block;background:#00E676;color:#003d1a;font-size:12px;font-weight:800;' +
        '             padding:9px 20px;border-radius:100px;letter-spacing:0.8px;">' +
        '&#10003;&nbsp; APPROVED' +
        '</span>' +
        '</td>' +
        '</tr></table>' +
        '</td></tr>' +

        // ── Claim ID strip ─────────────────────────────────────────────────────
        '<tr><td style="background:#0d2744;padding:14px 40px;">' +
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>' +
        '<td>' +
        '<p style="margin:0;font-size:10px;font-weight:700;color:#64788E;text-transform:uppercase;letter-spacing:1.2px;">Claim Number</p>' +
        '<p style="margin:4px 0 0;font-size:22px;font-weight:800;color:#BDD6F0;letter-spacing:0.5px;">' + escHtml(c.Name) + '</p>' +
        '</td>' +
        '<td style="text-align:right;vertical-align:middle;">' +
        '<p style="margin:0;font-size:11px;color:#64788E;">Confidence Score</p>' +
        '<p style="margin:4px 0 0;font-size:18px;font-weight:800;color:#00E676;">' + escHtml(score) + '</p>' +
        '</td>' +
        '</tr></table>' +
        '</td></tr>' +

        // ── Greeting ───────────────────────────────────────────────────────────
        '<tr><td style="background:#ffffff;padding:32px 40px 20px;">' +
        '<p style="margin:0;font-size:17px;font-weight:700;color:#1b3a6d;">Dear ' + escHtml(greeting) + ',</p>' +
        '<p style="margin:14px 0 0;font-size:14px;color:#4a5568;line-height:1.8;">' +
        'We are pleased to inform you that your warranty claim has been <strong style="color:#1a7f3c;">approved</strong>. ' +
        'Your claim has been processed and the details are summarised below. ' +
        'Our team will proceed with the next steps shortly.' +
        '</p>' +
        '</td></tr>' +

        // ── Amount tiles ───────────────────────────────────────────────────────
        '<tr><td style="background:#ffffff;padding:8px 40px 24px;">' +
        '<table role="presentation" width="100%" cellpadding="4" cellspacing="0" border="0"><tr>' +
            amountTile('Estimated Amount', estimatedAmt, '#e3f2fd', '#1565c0', '#1976d2') +
            amountTile('Approved Amount', approvedAmt, '#e8f5e9', '#2e7d32', '#388e3c') +
            '</tr></table>'+
        '</td></tr>' +

        // ── Details section ────────────────────────────────────────────────────
        '<tr><td style="background:#ffffff;padding:4px 40px 24px;">' +
        '<p style="margin:0 0 16px;font-size:11px;font-weight:700;color:#1b3a6d;text-transform:uppercase;' +
        '          letter-spacing:1px;border-bottom:2px solid #e8ecf2;padding-bottom:10px;">Claim Details</p>' +
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' +
        detailRow('Claim Type',      claimType,       false) +
        detailRow('Claim Reason',    claimReason,     false) +
        detailRow('Severity',        severity,        true) +
        detailRow('Initiation Date', initDate,        true) +
        detailRow('Processing',      processingMethod,true) +
        '</table>' +
        '</td></tr>' +

        // ── AI Summary (conditional) ───────────────────────────────────────────
        (String.isNotBlank(c.AI_Summary__c) ?
            '<tr><td style="background:#ffffff;padding:0 40px 28px;">' +
            '<div style="background:#f0f7ff;border-left:4px solid #00C8E8;border-radius:0 10px 10px 0;padding:16px 18px;">' +
            '<p style="margin:0 0 8px;font-size:10px;font-weight:700;color:#0176d3;text-transform:uppercase;letter-spacing:1.2px;">' +
            '&#128161; AI Assessment Summary</p>' +
            '<p style="margin:0;font-size:13px;color:#2d3748;line-height:1.7;">' + escHtml(c.AI_Summary__c) + '</p>' +
            '</div>' +
            '</td></tr>'
            : '') +

        // ── Divider ────────────────────────────────────────────────────────────
        '<tr><td style="background:#ffffff;padding:0 40px;">' +
        '<div style="border-top:1px solid #e8ecf2;"></div>' +
        '</td></tr>' +

        // ── Footer ─────────────────────────────────────────────────────────────
        '<tr><td style="background:#f7f9fc;border-top:2px solid #e8ecf2;padding:24px 40px;border-radius:0 0 16px 16px;">' +
        '<p style="margin:0;font-size:13px;color:#4a5568;line-height:1.7;">' +
        'If you have any questions, please contact our support team and reference claim number <strong style="color:#1b3a6d;">' + escHtml(c.Name) + '</strong>.' +
        '</p>' +
        '<p style="margin:16px 0 0;font-size:11px;color:#a0aec0;">' +
        'This is an automated notification from Electra Warranty Intelligence. Please do not reply to this email.' +
        '</p>' +
        '<p style="margin:8px 0 0;font-size:11px;color:#a0aec0;">' +
        '&copy; ' + currentYear + ' Electra Warranty Intelligence &nbsp;&middot;&nbsp; All rights reserved' +
        '</p>' +
        '</td></tr>' +

        '</table>' + // inner 600px
        '</td></tr>' +
        '</table>' + // outer wrapper
        '</body></html>';
    }

    // ── Email HTML helpers ────────────────────────────────────────────────────

    private static String amountTile(String label, String value, String bg, String labelColor, String valueColor) {
        return
        '<td style="width:33%;padding:4px;">' +
        '<div style="background:' + bg + ';border-radius:10px;padding:16px 12px;text-align:center;">' +
        '<p style="margin:0 0 6px;font-size:10px;font-weight:700;color:' + labelColor + ';text-transform:uppercase;letter-spacing:0.8px;">' + escHtml(label) + '</p>' +
        '<p style="margin:0;font-size:17px;font-weight:800;color:' + valueColor + ';letter-spacing:-0.3px;">' + escHtml(value) + '</p>' +
        '</div>' +
        '</td>';
    }

    private static String detailRow(String label, String value, Boolean shaded) {
        String bg = shaded ? '#f8fafb' : '#ffffff';
        return
        '<tr style="background:' + bg + ';">' +
        '<td style="padding:11px 12px 11px 0;width:42%;vertical-align:top;">' +
        '<span style="font-size:11px;font-weight:700;color:#5a6472;text-transform:uppercase;letter-spacing:0.6px;">' + escHtml(label) + '</span>' +
        '</td>' +
        '<td style="padding:11px 0 11px 12px;vertical-align:top;">' +
        '<span style="font-size:13px;color:#181818;line-height:1.5;">' + escHtml(value) + '</span>' +
        '</td>' +
        '</tr>';
    }

    private static String nextStep(String stepNum, String title, String body) {
        return
        '<tr><td style="vertical-align:top;padding:6px 0;">' +
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>' +
        '<td style="vertical-align:top;padding-right:14px;">' +
        '<div style="width:28px;height:28px;border-radius:50%;background:#0E1E35;color:#00C8E8;' +
        '            font-size:12px;font-weight:800;text-align:center;line-height:28px;">' + stepNum + '</div>' +
        '</td>' +
        '<td style="vertical-align:top;">' +
        '<p style="margin:0;font-size:13px;font-weight:700;color:#1b3a6d;">' + escHtml(title) + '</p>' +
        '<p style="margin:3px 0 0;font-size:12px;color:#4a5568;line-height:1.6;">' + body + '</p>' +
        '</td>' +
        '</tr></table>' +
        '</td></tr>';
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    private static String fmtAddress(Address addr) {
        if (addr == null) return '—';
        List<String> parts = new List<String>();
        if (String.isNotBlank(addr.getStreet()))      parts.add(addr.getStreet());
        if (String.isNotBlank(addr.getCity()))        parts.add(addr.getCity());
        if (String.isNotBlank(addr.getState()))       parts.add(addr.getState());
        if (String.isNotBlank(addr.getPostalCode()))  parts.add(addr.getPostalCode());
        if (String.isNotBlank(addr.getCountry()))     parts.add(addr.getCountry());
        return parts.isEmpty() ? '—' : String.join(parts, ', ');
    }

    private static String fmtCurrency(Decimal amount, String currencyCode) {
        if (amount == null) return '—';
        return currencyCode + ' ' + amount.setScale(2).format();
    }

    private static String escHtml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;');
    }
}