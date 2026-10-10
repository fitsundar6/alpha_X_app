import nodemailer, { Transporter } from 'nodemailer';
import { env } from '../config/environment';
import { logActivity } from '../utils/serverLogger';
import { maskEmail } from '../utils/pii_mask';

export interface SendPasswordResetEmailOptions {
  toEmail: string;
  resetToken: string;
  recipientName?: string;
}

export interface EmailDeliveryResult {
  delivered: boolean;
  mode: 'smtp' | 'preview_logger';
  previewUrl?: string;
  messageId?: string;
  error?: string;
}

export class EmailService {
  private static instance: EmailService;
  private transporter: Transporter | null = null;
  private isSmtpConfigured = false;

  private constructor() {
    this.initTransporter();
  }

  public static getInstance(): EmailService {
    if (!EmailService.instance) {
      EmailService.instance = new EmailService();
    }
    return EmailService.instance;
  }

  public isConfigured(): boolean {
    return this.isSmtpConfigured && this.transporter !== null;
  }

  /**
   * Verifies SMTP connection and authentication with the mail provider.
   */
  public async verifyConfiguration(): Promise<{ ok: boolean; reason?: string }> {
    if (!this.isConfigured() || !this.transporter) {
      return {
        ok: false,
        reason: 'SMTP configuration is incomplete. Required environment variables: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM.',
      };
    }
    try {
      await this.transporter.verify();
      return { ok: true };
    } catch (err: any) {
      return {
        ok: false,
        reason: `SMTP connection verification failed: ${err?.message || err}`,
      };
    }
  }

  private initTransporter(): void {
    if (env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS) {
      try {
        this.transporter = nodemailer.createTransport({
          host: env.SMTP_HOST,
          port: env.SMTP_PORT,
          secure: env.SMTP_SECURE,
          auth: {
            user: env.SMTP_USER,
            pass: env.SMTP_PASS,
          },
        });
        this.isSmtpConfigured = true;
        logActivity({
          statusCode: 200,
          activity: 'SMTP_CONFIGURED',
          reason: `Email delivery initialized via SMTP host: ${env.SMTP_HOST}:${env.SMTP_PORT}`,
        });
      } catch (err: any) {
        this.isSmtpConfigured = false;
        logActivity({
          statusCode: 500,
          activity: 'SMTP_CONFIG_FAILED',
          reason: `Failed to initialize SMTP transporter: ${err?.message || err}. Live email delivery unavailable.`,
          error: err,
        });
      }
    } else {
      this.isSmtpConfigured = false;
      if (env.NODE_ENV === 'production') {
        logActivity({
          statusCode: 500,
          activity: 'SMTP_CONFIG_MISSING',
          reason: 'Production environment is missing required SMTP credentials (SMTP_HOST, SMTP_USER, SMTP_PASS). Live email delivery is disabled.',
        });
      } else {
        logActivity({
          statusCode: 200,
          activity: 'EMAIL_PREVIEW_MODE',
          reason: 'No SMTP credentials provided in environment. Password reset emails will be dispatched via secure preview logger.',
        });
      }
    }
  }

  /**
   * Builds the branded HTML email content for Alpha X Gym password reset.
   */
  private buildResetEmailHtml(name: string, resetUrl: string, resetToken: string): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Alpha X Gym Password</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #0A0A0A;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #E0E0E0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: #141414;
      border: 1px solid #2A2A2A;
      border-radius: 16px;
      overflow: hidden;
      margin-top: 40px;
      margin-bottom: 40px;
    }
    .header {
      background: linear-gradient(180deg, #1A1A1A 0%, #141414 100%);
      padding: 36px 24px;
      text-align: center;
      border-bottom: 2px solid #D4A034;
    }
    .brand-title {
      color: #D4A034;
      font-size: 24px;
      font-weight: 900;
      letter-spacing: 2px;
      margin: 0;
      text-transform: uppercase;
    }
    .brand-subtitle {
      color: #A0A0A0;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 1.5px;
      margin-top: 6px;
      text-transform: uppercase;
    }
    .content {
      padding: 36px 32px;
      text-align: left;
    }
    .greeting {
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
      margin-bottom: 16px;
    }
    .paragraph {
      font-size: 14px;
      line-height: 1.6;
      color: #B0B0B0;
      margin-bottom: 24px;
    }
    .cta-container {
      text-align: center;
      margin: 32px 0;
    }
    .cta-button {
      background: linear-gradient(135deg, #E5B342 0%, #D4A034 100%);
      color: #000000 !important;
      text-decoration: none;
      font-size: 14px;
      font-weight: 800;
      letter-spacing: 1px;
      padding: 14px 32px;
      border-radius: 10px;
      display: inline-block;
      text-transform: uppercase;
      box-shadow: 0 4px 14px rgba(212, 160, 52, 0.35);
    }
    .token-box {
      background: #0A0A0A;
      border: 1px dashed #3D3D3D;
      border-radius: 8px;
      padding: 16px;
      margin: 20px 0;
      word-break: break-all;
      font-family: monospace;
      font-size: 12px;
      color: #D4A034;
      text-align: center;
    }
    .notice {
      background: rgba(212, 160, 52, 0.08);
      border-left: 3px solid #D4A034;
      padding: 12px 16px;
      border-radius: 4px;
      font-size: 12.5px;
      color: #D0D0D0;
      margin: 24px 0;
    }
    .footer {
      background: #0A0A0A;
      padding: 24px 32px;
      text-align: center;
      border-top: 1px solid #1F1F1F;
      font-size: 11px;
      color: #666666;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="brand-title">ALPHA X GYM</div>
      <div class="brand-subtitle">High Performance Training Portal</div>
    </div>
    <div class="content">
      <div class="greeting">Hello, ${name}</div>
      <p class="paragraph">
        We received a request to reset the password for your Alpha X Gym account. Click the button below to choose a new password.
      </p>
      <div class="cta-container">
        <a href="${resetUrl}" class="cta-button" target="_blank">Reset Your Password</a>
      </div>
      <div class="notice">
        <strong>Important:</strong> This password reset link is valid for <strong>15 minutes</strong> and can only be used once. If you did not make this request, you can safely ignore this email — your account remains secure.
      </div>
      <p class="paragraph" style="font-size: 12px; color: #777777;">
        If you are using the mobile app and prompted to enter your reset token manually, you may use the token below:
      </p>
      <div class="token-box">${resetToken}</div>
    </div>
    <div class="footer">
      Alpha X Gym • Confidential & Secure Authentication System<br>
      Automated message — please do not reply directly to this email.
    </div>
  </div>
</body>
</html>`;
  }

  /**
   * Dispatches the password recovery email via SMTP or fallback preview logger.
   */
  public async sendPasswordResetEmail(options: SendPasswordResetEmailOptions): Promise<EmailDeliveryResult> {
    const { toEmail, resetToken, recipientName } = options;
    const name = recipientName || 'Athlete';
    const baseUrl = env.APP_URL.replace(/\/+$/, '');
    const resetUrl = `${baseUrl}/reset-password?token=${encodeURIComponent(resetToken)}`;

    const mailOptions = {
      from: env.SMTP_FROM,
      to: toEmail,
      subject: 'Reset Your Alpha X Gym Password',
      text: `Hello ${name},\n\nWe received a request to reset your Alpha X Gym password.\n\nPlease visit the following link to choose a new password:\n${resetUrl}\n\nReset Token: ${resetToken}\n\nThis link expires in 15 minutes and can only be used once.\nIf you did not request this, please ignore this email.\n\nAlpha X Gym`,
      html: this.buildResetEmailHtml(name, resetUrl, resetToken),
    };

    if (this.isSmtpConfigured && this.transporter) {
      try {
        const info = await this.transporter.sendMail(mailOptions);
        logActivity({
          statusCode: 200,
          activity: 'SMTP_EMAIL_SENT',
          reason: `Password reset email dispatched via SMTP to ${maskEmail(toEmail)}`,
          details: { messageId: info.messageId, recipient: maskEmail(toEmail) },
        });
        return {
          delivered: true,
          mode: 'smtp',
          messageId: info.messageId,
        };
      } catch (err: any) {
        logActivity({
          statusCode: 500,
          activity: 'SMTP_EMAIL_ERROR',
          reason: `Failed to deliver email via SMTP to ${maskEmail(toEmail)}: ${err?.message || err}`,
          error: err,
        });
        return {
          delivered: false,
          mode: 'smtp',
          error: `SMTP delivery failed: ${err?.message || 'Transport error'}`,
        };
      }
    }

    // In production, never silently fall back to preview logger or claim successful delivery
    if (env.NODE_ENV === 'production') {
      logActivity({
        statusCode: 500,
        activity: 'SMTP_DELIVERY_REJECTED',
        reason: `Email delivery requested for ${maskEmail(toEmail)} but SMTP is unconfigured in production environment.`,
      });
      return {
        delivered: false,
        mode: 'smtp',
        error: 'SMTP service is not configured in production environment',
      };
    }

    // Preview logger fallback (ONLY for non-production environments: dev, preview, test)
    logActivity({
      statusCode: 200,
      activity: 'RESET_EMAIL_PREVIEW_GENERATED',
      reason: `Password reset email dispatched for ${maskEmail(toEmail)} (preview mode)`,
      details: {
        to: maskEmail(toEmail),
        expiresInMinutes: 15,
      },
    });

    return {
      delivered: true,
      mode: 'preview_logger',
      previewUrl: resetUrl,
    };
  }
}

export const emailService = EmailService.getInstance();

