# Author: Stein-N, Claude
# Description:
#   No_Save is a method for GTA Online to replay Heists Finales again but still get the money reward.
#   There are many scripts for the program AutoHotkey, because i had some issues with the reliablity 
#   of the AHK script i decided to write a Script for Powershell, to rely soly on windows own tools.
#
# License: MIT



# --- Konfiguration ---
$RuleName = "No_Save"   # DisplayName for the Firewall rule

# --- self-elevation: scripts restarts as admin and with a hidden console ---
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

# --- Status-Frame + Hotkeys ---
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
    private Label lbl;

    public StatusForm() {
        this.FormBorderStyle = FormBorderStyle.None;
        this.BackColor       = Color.FromArgb(255, 255, 225); // Tooltip-Gelb
        this.TopMost         = true;
        this.ShowInTaskbar   = false;
        this.StartPosition   = FormStartPosition.Manual;
        this.Location        = new Point(5, 5);             // oben links

        lbl = new Label();
        lbl.AutoSize  = true;
        lbl.Location  = new Point(4, 3);
        lbl.Font      = new Font("Segoe UI", 9F, FontStyle.Bold);
        lbl.BackColor = Color.Transparent;
        this.Controls.Add(lbl);

        RegisterHotKey(this.Handle, ID_ENABLE,  MOD_CONTROL, VK_F9);
        RegisterHotKey(this.Handle, ID_DISABLE, MOD_CONTROL, VK_F12);
        RegisterHotKey(this.Handle, ID_QUIT,    MOD_CONTROL, VK_F4);
    }

    // Windows is never active -> never steals the focus
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            return cp;
        }
    }

    public void SetStatus(string text, Color color) {
        if (this.InvokeRequired) { this.Invoke(new Action(() => SetStatus(text, color))); return; }
        lbl.Text      = text;
        lbl.ForeColor = color;
        this.ClientSize = new Size(lbl.PreferredWidth + 4, lbl.PreferredHeight + 2);
        this.Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        using (Pen p = new Pen(Color.FromArgb(118, 118, 118))) {
            e.Graphics.DrawRectangle(p, 0, 0, this.Width - 1, this.Height - 1);
        }
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

# --- Show the Status - Reads the Firewall rule if it is active or not ---
function Show-Status {
    $rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if (-not $rule) {
        $form.SetStatus("Rule '$RuleName' not found", [System.Drawing.Color]::Red)
        return
    }
    if ($rule.Enabled -eq "True") {
        $form.SetStatus("$RuleName : Active",   [System.Drawing.Color]::Green)
    } else {
        $form.SetStatus("$RuleName : Inactive", [System.Drawing.Color]::Red)
    }
}

# --- set the rule to active or inactive ---
function Set-Rule([bool]$enable) {
    if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
        Show-Status
        return
    }
    if ($enable) { Enable-NetFirewallRule  -DisplayName $RuleName }
    else         { Disable-NetFirewallRule -DisplayName $RuleName }
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
Show-Status   # Shows the Status at the beginning

try {
    [System.Windows.Forms.Application]::Run($form)
}
finally {
    # Rule gets deactivated when closing to prevent it from beeing active after usage
    if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) {
        Disable-NetFirewallRule -DisplayName $RuleName
    }
}