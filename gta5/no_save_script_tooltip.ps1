# Author: Stein-N, Claude
# Description:
#   No_Save is a method for GTA Online to replay Heists Finales again but still get the money reward.
#   There are many scripts for the program AutoHotkey, because i had some issues with the reliablity 
#   of the AHK script i decided to write a Script for Powershell, to rely soly on windows own tools.
#
# License: MIT


# Configuration
$FirewallRuleName = "GTA_5_No_Save"


# Elevate the Script to a admin powershell window, this is needed since the Frame needs to listen to keystrokes
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

# Check if outgoing firewall rule is already set.
# If the rule not exists it will be added
$rule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -DisplayName $FirewallRuleName -Direction Outbound -Action Block -RemoteAddress 192.81.241.171 -Profile Any -Protocol Any -Enabled False
}

# Create the Tooltip Frame and register global hotkeys
Add-Type @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class StatusForm : Form {
    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private const int WM_HOTKEY = 0x0312;
    private const uint MOD_CONTROL = 0x0002;
    private const uint VK_F9  = 0x78;
    private const uint VK_F12 = 0x7B;
    private const uint VK_F4  = 0x73;

    public const int ID_ENABLE  = 1;
    public const int ID_DISABLE = 2;
    public const int ID_QUIT    = 3;

    public event Action<int> HotKeyPressed;
    private Label lblPrefix;
    private Label lblStatus;

    public StatusForm() {
        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor       = Color.FromArgb(255, 255, 225);
        this.TopMost         = true;
        this.ShowInTaskbar   = false;
        this.StartPosition   = FormStartPosition.Manual;
        this.Location        = new Point(5, 5);

        var font = new Font("Segoe UI", 12F, FontStyle.Bold);

        lblPrefix = new Label();
        lblPrefix.AutoSize  = true;
        lblPrefix.Location  = new Point(1, 1);
        lblPrefix.Font      = font;
        lblPrefix.BackColor = Color.Transparent;
        lblPrefix.ForeColor = Color.Black;
        this.Controls.Add(lblPrefix);

        lblStatus = new Label();
        lblStatus.AutoSize  = true;
        lblStatus.Font      = font;
        lblStatus.BackColor = Color.Transparent;
        this.Controls.Add(lblStatus);

        RegisterHotKey(this.Handle, ID_ENABLE,  MOD_CONTROL, VK_F9);
        RegisterHotKey(this.Handle, ID_DISABLE, MOD_CONTROL, VK_F12);
        RegisterHotKey(this.Handle, ID_QUIT,    MOD_CONTROL, VK_F4);
    }

    // Window can never be focused, but will always be on top
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            return cp;
        }
    }

    public void SetStatus(string prefix, string status, Color statusColor) {
        lblPrefix.Text     = prefix;
        lblStatus.Text     = status;
        lblStatus.ForeColor = statusColor;
        lblStatus.Location = new Point(lblPrefix.PreferredWidth + 1, 1);
        this.ClientSize    = new Size(lblPrefix.PreferredWidth + lblStatus.PreferredWidth + 2, lblPrefix.PreferredHeight);
        this.Invalidate();
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && HotKeyPressed != null)
            HotKeyPressed((int)m.WParam);
        base.WndProc(ref m);
    }

    protected override void Dispose(bool disposing) {
        UnregisterHotKey(this.Handle, ID_ENABLE);
        UnregisterHotKey(this.Handle, ID_DISABLE);
        UnregisterHotKey(this.Handle, ID_QUIT);
        base.Dispose(disposing);
    }
}
'@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

# Set the Text inside the Tooltip
function Show-Status {
    $rule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
    if (-not $rule) {
        $form.SetStatus("Rule '$FirewallRuleName' :", "not found", [System.Drawing.Color]::Red)
        return
    }
    if ($rule.Enabled -eq "True") {
        $form.SetStatus("$FirewallRuleName :", "Active", [System.Drawing.Color]::Green)
    } else {
        $form.SetStatus("$FirewallRuleName :", "Inactive", [System.Drawing.Color]::Red)
    }
}

# Change the rule status
function Set-Rule([bool]$enable) {
    if (-not (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue)) {
        Show-Status
        return
    }
    if ($enable) { Enable-NetFirewallRule  -DisplayName $FirewallRuleName }
    else         { Disable-NetFirewallRule -DisplayName $FirewallRuleName }
    Show-Status
}

$form = New-Object StatusForm
$form.add_HotKeyPressed({
    param($id)
    switch ($id) {
        ([StatusForm]::ID_ENABLE)  { Set-Rule $true }
        ([StatusForm]::ID_DISABLE) { Set-Rule $false }
        ([StatusForm]::ID_QUIT)    { $form.Close() }
    }
})

$form.Show()
# Show the initial state of the rule, should always be inactive and present
Show-Status

try {
    [System.Windows.Forms.Application]::Run($form)
}
finally {
    # Deactivate rule when closing the script
    if (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue) {
        Disable-NetFirewallRule -DisplayName $FirewallRuleName
    }
}