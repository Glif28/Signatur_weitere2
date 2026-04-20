#Requires -Version 5.0
[CmdletBinding()]
param()

$windowCode = @"
using System;
using System.Runtime.InteropServices;
public class Window {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

try {
    Add-Type -TypeDefinition $windowCode -Language CSharp -ErrorAction SilentlyContinue
    $consolePtr = [Window]::GetConsoleWindow()
    if ($consolePtr -ne [IntPtr]::Zero) {
        [Window]::ShowWindow($consolePtr, 0) | Out-Null
    }
} catch { }

$OutputEncoding = [System.Text.UTF8Encoding]::new($true)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($true)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8BOM'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ShowLegal = $true
$script:DarkMode = $false
$script:Colors = @{
    GrayBg = [System.Drawing.Color]::FromArgb(240, 240, 240)
    DarkBg = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Primary = [System.Drawing.Color]::FromArgb(0, 120, 215)
    PrimaryHover = [System.Drawing.Color]::FromArgb(0, 100, 180)
    DangerColor = [System.Drawing.Color]::FromArgb(220, 50, 50)
    SuccessColor = [System.Drawing.Color]::FromArgb(50, 170, 100)
    SidebarGray = [System.Drawing.Color]::FromArgb(230, 230, 230)
    SidebarDark = [System.Drawing.Color]::FromArgb(45, 45, 50)
}

function Create-AppIcon {
    $bitmap = New-Object System.Drawing.Bitmap(32, 32)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $blueBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 120, 215))
    $graphics.FillEllipse($blueBrush, 2, 2, 28, 28)
    
    $whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    
    $graphics.DrawRectangle($whitePen, 8, 10, 16, 12)
    $graphics.DrawLine($whitePen, 8, 10, 16, 16)
    $graphics.DrawLine($whitePen, 24, 10, 16, 16)
    
    $graphics.Dispose()
    return $bitmap
}

function Create-IconBitmap {
    param([string]$Type, [int]$Size = 24)
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    
    switch($Type) {
        "Preview" { $graphics.DrawEllipse($pen, 4, 6, 16, 12); $graphics.FillEllipse($brush, 10, 10, 4, 4) }
        "Copy" { $graphics.DrawRectangle($pen, 4, 4, 12, 12); $graphics.DrawRectangle($pen, 8, 8, 12, 12) }
        "Save" { $graphics.DrawRectangle($pen, 2, 2, 20, 20); $graphics.FillRectangle($brush, 4, 4, 16, 8); $graphics.FillRectangle($brush, 6, 14, 12, 2) }
        "Legal" { $font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold); $graphics.DrawString("", $font, $brush, 2, -2); $font.Dispose() }
        "Info" { $font = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold); $graphics.DrawString("", $font, $brush, 7, -2); $font.Dispose() }
        "Reset" { $font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold); $graphics.DrawString("", $font, $brush, 2, 0); $font.Dispose() }
    }
    $graphics.Dispose()
    return $bitmap
}

function Format-LineBreak ($text, $width = 75) {
    if (!$text) { return "" }
    $cleanText = $text -replace "`n", " "
    $words = $cleanText -split ' '
    $lines = @()
    $currentLine = ""
    foreach ($word in $words) {
        if (($currentLine.Length + $word.Length + 1) -le $width) {
            $currentLine += $(if ($currentLine) { " " } else { "" }) + $word
        } else {
            $lines += $currentLine
            $currentLine = $word
        }
    }
    $lines += $currentLine
    return $lines -join "`n"
}

function CreateModernButton {
    param([string]$Text, [int]$Top, [System.Drawing.Color]$BackColor, [System.Drawing.Color]$HoverColor, [string]$IconType = "")
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = [System.Drawing.Point]::new(10, $Top)
    $btn.Width = 180
    $btn.Height = 42
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseDownBackColor = $HoverColor
    $btn.FlatAppearance.MouseOverBackColor = $HoverColor
    $btn.BackColor = $BackColor
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.TextAlign = "MiddleCenter"
    $btn.Font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    if ($IconType -ne "") {
        $btn.Image = Create-IconBitmap $IconType 16
        $btn.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btn.TextImageRelation = "ImageBeforeText"
    }
    return $btn
}

function CreateTextBox {
    param([int]$Top, [string]$Text = "")
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = [System.Drawing.Point]::new(20, $Top)
    $tb.Width = 280
    $tb.Height = 32
    $tb.Font = [System.Drawing.Font]::new("Segoe UI", 10)
    $tb.BorderStyle = "FixedSingle"
    $tb.Text = $Text
    $tb.ForeColor = [System.Drawing.Color]::Black
    $tb.BackColor = [System.Drawing.Color]::White
    $tb.Add_TextChanged({ & $UpdatePreview })
    return $tb
}

# --- HAUPTFENSTER MIT GRAUER FARBE (OHNE TITELLEISTE) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Outlook Signature Studio - v3.0"
$form.Size = [System.Drawing.Size]::new(1250, 910)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MinimumSize = [System.Drawing.Size]::new(1200, 800)
$form.BackColor = $script:Colors.GrayBg
$form.ShowInTaskbar = $true
$form.TopMost = $true

# --- APP ICON ---
$appIcon = Create-AppIcon
$form.Icon = [System.Drawing.Icon]::FromHandle($appIcon.GetHicon())

# --- SIDEBAR ---
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Width = 200
$sidebar.Dock = "Left"
$sidebar.BackColor = $script:Colors.SidebarGray
$sidebar.BorderStyle = "FixedSingle"
$sidebar.AutoScroll = $true
$form.Controls.Add($sidebar)

$lblMenu = New-Object System.Windows.Forms.Label
$lblMenu.Text = "MENÜ"
$lblMenu.Location = [System.Drawing.Point]::new(20, 15)
$lblMenu.Font = [System.Drawing.Font]::new("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblMenu.AutoSize = $true
$sidebar.Controls.Add($lblMenu)

# --- BUTTONS ---
$btnPreview = CreateModernButton "VORSCHAU" 45 $script:Colors.Primary $script:Colors.PrimaryHover "Preview"
$btnCopy = CreateModernButton "KOPIEREN" 95 $script:Colors.SuccessColor ([System.Drawing.Color]::FromArgb(40, 150, 90)) "Copy"
$btnSave = CreateModernButton "SPEICHERN" 145 $script:Colors.DangerColor ([System.Drawing.Color]::FromArgb(200, 40, 40)) "Save"
$btnToggleLegal = CreateModernButton "RECHTLICH" 195 ([System.Drawing.Color]::FromArgb(100, 100, 100)) ([System.Drawing.Color]::FromArgb(80, 80, 80)) "Legal"
$btnInfo = CreateModernButton "INFO" 245 ([System.Drawing.Color]::FromArgb(100, 150, 200)) ([System.Drawing.Color]::FromArgb(80, 130, 180)) "Info"

$sidebar.Controls.AddRange(@($btnPreview, $btnCopy, $btnSave, $btnToggleLegal, $btnInfo))

# --- SPRACHE ---
$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = "SPRACHE"
$lblLang.Location = [System.Drawing.Point]::new(20, 310)
$lblLang.Font = [System.Drawing.Font]::new("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblLang.ForeColor = [System.Drawing.Color]::Gray
$lblLang.AutoSize = $true
$sidebar.Controls.Add($lblLang)

$langBox = New-Object System.Windows.Forms.ComboBox
$langBox.Location = [System.Drawing.Point]::new(15, 335)
$langBox.Width = 170
$langBox.Items.AddRange(@("DEUTSCH", "ENGLISH"))
$langBox.SelectedIndex = 0
$langBox.DropDownStyle = "DropDownList"
$langBox.FlatStyle = "Flat"
$langBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$sidebar.Controls.Add($langBox)

# --- ANZEIGE-OPTIONEN ---
$lblCheckboxSection = New-Object System.Windows.Forms.Label
$lblCheckboxSection.Text = "ANZEIGE-OPTIONEN"
$lblCheckboxSection.Location = [System.Drawing.Point]::new(20, 370)
$lblCheckboxSection.Font = [System.Drawing.Font]::new("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblCheckboxSection.ForeColor = [System.Drawing.Color]::Gray
$lblCheckboxSection.AutoSize = $true
$sidebar.Controls.Add($lblCheckboxSection)

$chkGreeting = New-Object System.Windows.Forms.CheckBox
$chkGreeting.Text = "Grusformel"
$chkGreeting.Location = [System.Drawing.Point]::new(15, 395)
$chkGreeting.Checked = $true
$chkGreeting.AutoSize = $true
$chkGreeting.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$chkGreeting.ForeColor = [System.Drawing.Color]::Black
$chkGreeting.Add_CheckedChanged({ & $UpdatePreview })
$sidebar.Controls.Add($chkGreeting)

$chkDefault = New-Object System.Windows.Forms.CheckBox
$chkDefault.Text = "Standard"
$chkDefault.Location = [System.Drawing.Point]::new(15, 420)
$chkDefault.AutoSize = $true
$chkDefault.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$chkDefault.ForeColor = [System.Drawing.Color]::Black
$sidebar.Controls.Add($chkDefault)

# --- DARK MODE ---
$lblDarkModeSection = New-Object System.Windows.Forms.Label
$lblDarkModeSection.Text = "DARK MODE"
$lblDarkModeSection.Location = [System.Drawing.Point]::new(20, 796)
$lblDarkModeSection.Font = [System.Drawing.Font]::new("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblDarkModeSection.ForeColor = [System.Drawing.Color]::Gray
$lblDarkModeSection.AutoSize = $true
$sidebar.Controls.Add($lblDarkModeSection)

$toggleBackground = New-Object System.Windows.Forms.Panel
$toggleBackground.Size = [System.Drawing.Size]::new(70, 35)
$toggleBackground.Location = [System.Drawing.Point]::new(10, 821)
$toggleBackground.BackColor = [System.Drawing.Color]::LightGray
$toggleBackground.BorderStyle = "None"
$toggleBackground.Cursor = [System.Windows.Forms.Cursors]::Hand
$sidebar.Controls.Add($toggleBackground)

$toggleButton = New-Object System.Windows.Forms.Panel
$toggleButton.Size = [System.Drawing.Size]::new(30, 30)
$toggleButton.Location = [System.Drawing.Point]::new(2, 2)
$toggleButton.BackColor = [System.Drawing.Color]::White
$toggleButton.BorderStyle = "None"
$toggleBackground.Controls.Add($toggleButton)

# --- EINGABEBEREICH (OHNE HEADER) ---
$inputContainer = New-Object System.Windows.Forms.Panel
$inputContainer.Location = [System.Drawing.Point]::new(200, 0)
$inputContainer.Size = [System.Drawing.Size]::new(410, 950)
$inputContainer.BackColor = $script:Colors.GrayBg
$inputContainer.BorderStyle = "FixedSingle"
$inputContainer.AutoScroll = $true
$form.Controls.Add($inputContainer)

# --- INPUT FELDER ---
$fields = @(
    @{ Label = "VORNAME"; Prefix = "" }
    @{ Label = "NACHNAME"; Prefix = "" }
    @{ Label = "POSITION 1"; Prefix = "" }
    @{ Label = "POSITION 2"; Prefix = "" }
    @{ Label = "E-MAIL"; Prefix = "" }
    @{ Label = "TELEFON"; Prefix = "T: " }
    @{ Label = "MOBIL"; Prefix = "M: " }
    @{ Label = "FIRMA"; Prefix = "" }
    @{ Label = "STRASSE"; Prefix = "" }
    @{ Label = "PLZ"; Prefix = "" }
    @{ Label = "ORT"; Prefix = "" }
    @{ Label = "LAND"; Prefix = "" }
    @{ Label = "WEBSEITE"; Prefix = "www." }
)

$textboxes = @()
$checkboxes = @()
$currentTop = 15

for ($i = 0; $i -lt $fields.Count; $i++) {
    $field = $fields[$i]
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $field.Label
    $lbl.Location = [System.Drawing.Point]::new(20, $currentTop)
    $lbl.Font = [System.Drawing.Font]::new("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::Gray
    $lbl.AutoSize = $true
    $inputContainer.Controls.Add($lbl)
    
    $tb = CreateTextBox ($currentTop + 18) $field.Prefix
    $inputContainer.Controls.Add($tb)
    $textboxes += $tb
    
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = ""
    $chk.Location = [System.Drawing.Point]::new(310, $currentTop + 20)
    $chk.Checked = $true
    $chk.AutoSize = $true
    $chk.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    $chk.ForeColor = [System.Drawing.Color]::Black
    $chk.Add_CheckedChanged({ & $UpdatePreview })
    $inputContainer.Controls.Add($chk)
    $checkboxes += $chk
    
    $currentTop += 55
}

$btnReset = CreateModernButton "RESET" ($currentTop + 10) ([System.Drawing.Color]::FromArgb(200, 100, 100)) ([System.Drawing.Color]::FromArgb(180, 80, 80)) "Reset"
$btnReset.Location = [System.Drawing.Point]::new(10, $currentTop + 10)
$btnReset.Width = 190
$inputContainer.Controls.Add($btnReset)

# --- KURZNAMEN ---
$chkVorname = $checkboxes[0]
$chkNachname = $checkboxes[1]
$chkPos1 = $checkboxes[2]
$chkPos2 = $checkboxes[3]
$chkEmail = $checkboxes[4]
$chkPhone = $checkboxes[5]
$chkMobile = $checkboxes[6]
$chkFirma = $checkboxes[7]
$chkStrasse = $checkboxes[8]
$chkPlz = $checkboxes[9]
$chkOrt = $checkboxes[10]
$chkLand = $checkboxes[11]
$chkWebseite = $checkboxes[12]

# --- VORSCHAU (OHNE HEADER) ---
$previewPanel = New-Object System.Windows.Forms.Panel
$previewPanel.Location = [System.Drawing.Point]::new(620, 0)
$previewPanel.Size = [System.Drawing.Size]::new(580, 950)
$previewPanel.BackColor = $script:Colors.GrayBg
$previewPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($previewPanel)

$preview = New-Object System.Windows.Forms.RichTextBox
$preview.Location = [System.Drawing.Point]::new(10, 10)
$preview.Size = [System.Drawing.Size]::new(560, 930)
$preview.ReadOnly = $true
$preview.BorderStyle = "FixedSingle"
$preview.BackColor = [System.Drawing.Color]::White
$preview.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$preview.ScrollBars = "Vertical"
$previewPanel.Controls.Add($preview)

# --- TRANSLATIONS ---
function Get-Translations {
    if ($langBox.SelectedIndex -eq 0) {
        return @{
            Greeting = "Mit freundlichen Grüßen"
            Disclaimer = "The information contained within this communication is confidential and may be legally privileged. If you are not the intended recipient, you are hereby notified that any dissemination, copying or distribution of this communication, or the taking of any action in reliance on the contents of this communication, is strictly prohibited. Please notify the sender of this e-mail immediately and delete or destroy all copies of this communication."
            Footer = "Sitz: Wiesbaden, Registergericht: Amtsgericht Wiesbaden, HRB 9569`nGeschäftsführer: Alexander Kraus, Rainer Schwöbel, Dr. Matthias Wellers"
        }
    } else {
        return @{
            Greeting = "Best Regards"
            Disclaimer = "The information contained within this communication is confidential and may be legally privileged. If you are not the intended recipient, you are hereby notified that any dissemination, copying or distribution of this communication, or the taking of any action in reliance on the contents of this communication, is strictly prohibited. Please notify the sender of this e-mail immediately and delete or destroy all copies of this communication."
            Footer = "Registered Office: Wiesbaden, District Court: Amtsgericht Wiesbaden, HRB 9569`nManaging Directors: Alexander Kraus, Jan Marek, Rainer Schwöbel, Dr. Matthias Wellers"
        }
    }
}

# --- PREVIEW UPDATE ---
$UpdatePreview = {
    $preview.Clear()
    $trans = Get-Translations
    
    if ($chkGreeting.Checked) { 
        $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 10)
        $preview.AppendText("$($trans.Greeting),`n`n") 
    }

    if (($chkVorname.Checked -and $textboxes[0].Text.Trim() -ne "") -or ($chkNachname.Checked -and $textboxes[1].Text.Trim() -ne "")) {
        $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $vorname = if ($chkVorname.Checked) { $textboxes[0].Text.Trim() } else { "" }
        $nachname = if ($chkNachname.Checked) { $textboxes[1].Text.Trim() } else { "" }
        $fullName = "$vorname $nachname".Trim()
        if ($fullName -ne "") { $preview.AppendText("$fullName`n`n") }
    }
    
    if ($chkPos1.Checked -and $textboxes[2].Text.Trim() -ne "") {
        $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 10)
        $preview.AppendText("$($textboxes[2].Text)`n")
    }
    
    if ($chkPos2.Checked -and $textboxes[3].Text.Trim() -ne "") { 
        $preview.AppendText("$($textboxes[3].Text)`n") 
    }
    
    $preview.AppendText("`n")
    
    if ($chkEmail.Checked -and $textboxes[4].Text.Trim() -ne "") {
        $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Underline)
        $preview.AppendText("$($textboxes[4].Text)`n")
    }
    
    $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 10)
    $contactInfo = @()
    if ($chkPhone.Checked -and $textboxes[5].Text.Trim() -ne "") { $contactInfo += $textboxes[5].Text }
    if ($chkMobile.Checked -and $textboxes[6].Text.Trim() -ne "") { $contactInfo += $textboxes[6].Text }
    if ($contactInfo.Count -gt 0) { $preview.AppendText(($contactInfo -join " | ") + "`n") }
    
    # Firma, Straße, PLZ, Ort, Land und Webseite – alle in einer Zeile
    $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 10)
    $companyLine = @()
    if ($chkFirma.Checked -and $textboxes[7].Text.Trim() -ne "") { $companyLine += $textboxes[7].Text.Trim() }
    if ($chkStrasse.Checked -and $textboxes[8].Text.Trim() -ne "") { $companyLine += $textboxes[8].Text.Trim() }
    if ($chkPlz.Checked -and $textboxes[9].Text.Trim() -ne "") {
        if ($chkOrt.Checked -and $textboxes[10].Text.Trim() -ne "") {
            $companyLine += "$($textboxes[9].Text.Trim()) $($textboxes[10].Text.Trim())"
        } else {
            $companyLine += $textboxes[9].Text.Trim()
        }
    } elseif ($chkOrt.Checked -and $textboxes[10].Text.Trim() -ne "") {
        $companyLine += $textboxes[10].Text.Trim()
    }
    if ($chkLand.Checked -and $textboxes[11].Text.Trim() -ne "") { $companyLine += $textboxes[11].Text.Trim() }
    if ($chkWebseite.Checked -and $textboxes[12].Text.Trim() -ne "") { $companyLine += $textboxes[12].Text.Trim() }
    if ($companyLine.Count -gt 0) { $preview.AppendText(($companyLine -join " | ") + "`n") }
    
    $preview.AppendText("`n")
    
    if ($script:ShowLegal) {
        $preview.SelectionColor = [System.Drawing.Color]::Gray
        $preview.SelectionFont = [System.Drawing.Font]::new("Segoe UI", 7)
        $disclaimerWrapped = Format-LineBreak $trans.Disclaimer 75
        $preview.AppendText("$disclaimerWrapped`n")
        $preview.AppendText("`n$("_" * 100)`n`n")
        $preview.AppendText("$($trans.Footer)")
    }
}

# --- BUTTON EVENTS ---
$btnPreview.Add_Click({ & $UpdatePreview })

$btnSave.Add_Click({
    if (($textboxes[0].Text.Trim() -eq "" -and $textboxes[1].Text.Trim() -eq "") -or ($chkVorname.Checked -eq $false -and $chkNachname.Checked -eq $false)) {
        [System.Windows.Forms.MessageBox]::Show("Vorname und/oder Nachname erforderlich!", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $sigName = if ($chkNachname.Checked -and $textboxes[1].Text.Trim() -ne "") { $textboxes[1].Text.Trim() } else { $textboxes[0].Text.Trim() }
    $path = "$env:APPDATA\Microsoft\Signatures"
    
    if (!(Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    
    try {
        $trans = Get-Translations
        $htmlBody = "<html><head><meta charset='UTF-8'><style>body { font-family: Segoe UI, Arial; }</style></head><body>"
        
        if ($chkGreeting.Checked) { $htmlBody += "<p>$($trans.Greeting),</p>" }
        
        if (($chkVorname.Checked -and $textboxes[0].Text.Trim() -ne "") -or ($chkNachname.Checked -and $textboxes[1].Text.Trim() -ne "")) {
            $vorname = if ($chkVorname.Checked) { $textboxes[0].Text.Trim() } else { "" }
            $nachname = if ($chkNachname.Checked) { $textboxes[1].Text.Trim() } else { "" }
            $fullName = "$vorname $nachname".Trim()
            if ($fullName -ne "") { $htmlBody += "<p style='font-weight: bold; font-size: 12pt;'>$fullName</p>" }
        }
        
        if ($chkPos1.Checked -and $textboxes[2].Text.Trim() -ne "") {
            $htmlBody += "<p style='font-size: 10pt;'>$($textboxes[2].Text)</p>"
        }
        
        if ($chkPos2.Checked -and $textboxes[3].Text.Trim() -ne "") { 
            $htmlBody += "<p style='font-size: 10pt;'>$($textboxes[3].Text)</p>" 
        }
        
        if ($chkEmail.Checked -and $textboxes[4].Text.Trim() -ne "") {
            $htmlBody += "<p style='text-decoration: underline;'>$($textboxes[4].Text)</p>"
        }
        
        $contactInfo = @()
        if ($chkPhone.Checked -and $textboxes[5].Text.Trim() -ne "") { $contactInfo += $textboxes[5].Text }
        if ($chkMobile.Checked -and $textboxes[6].Text.Trim() -ne "") { $contactInfo += $textboxes[6].Text }
        if ($contactInfo.Count -gt 0) { $htmlBody += "<p>$($contactInfo -join ' | ')</p>" }
        
        # Firma, Straße, PLZ, Ort, Land und Webseite – alle in einer Zeile (HTML)
        $companyLine = @()
        if ($chkFirma.Checked -and $textboxes[7].Text.Trim() -ne "") { $companyLine += $textboxes[7].Text.Trim() }
        if ($chkStrasse.Checked -and $textboxes[8].Text.Trim() -ne "") { $companyLine += $textboxes[8].Text.Trim() }
        if ($chkPlz.Checked -and $textboxes[9].Text.Trim() -ne "") {
            if ($chkOrt.Checked -and $textboxes[10].Text.Trim() -ne "") {
                $companyLine += "$($textboxes[9].Text.Trim()) $($textboxes[10].Text.Trim())"
            } else {
                $companyLine += $textboxes[9].Text.Trim()
            }
        } elseif ($chkOrt.Checked -and $textboxes[10].Text.Trim() -ne "") {
            $companyLine += $textboxes[10].Text.Trim()
        }
        if ($chkLand.Checked -and $textboxes[11].Text.Trim() -ne "") { $companyLine += $textboxes[11].Text.Trim() }
        if ($chkWebseite.Checked -and $textboxes[12].Text.Trim() -ne "") { $companyLine += $textboxes[12].Text.Trim() }
        if ($companyLine.Count -gt 0) { $htmlBody += "<p>$($companyLine -join ' | ')</p>" }
        
        if ($script:ShowLegal) {
            $disclaimerWrapped = Format-LineBreak $trans.Disclaimer 85
            $htmlBody += "<p style='font-size: 7pt; color: #666;'>$($disclaimerWrapped -replace "`n", "<br>")"
            $htmlBody += "<p>$("_" * 100)</p>"
            $htmlBody += "<p>$($trans.Footer -replace "`n", "<br/>")</p>"
        }
        
        $htmlBody += "</body></html>"
        
        $htmlBody | Out-File "$path\$sigName.htm" -Encoding utf8BOM -Force
        $preview.Text | Out-File "$path\$sigName.txt" -Encoding utf8BOM -Force
        
        [System.Windows.Forms.MessageBox]::Show("Signatur gespeichert!", "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Fehler: $_", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnCopy.Add_Click({
    if (($textboxes[0].Text.Trim() -eq "" -and $textboxes[1].Text.Trim() -eq "") -or ($chkVorname.Checked -eq $false -and $chkNachname.Checked -eq $false)) {
        [System.Windows.Forms.MessageBox]::Show("Vorname und/oder Nachname erforderlich!", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    try {
        [System.Windows.Forms.Clipboard]::SetText($preview.Text)
        [System.Windows.Forms.MessageBox]::Show("Kopiert!", "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Fehler: $_", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnReset.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Alle Eingabefelder löschen?", "Bestätigung", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        for ($i = 0; $i -lt $textboxes.Count; $i++) {
            $textboxes[$i].Text = $fields[$i].Prefix
        }
        & $UpdatePreview
    }
})

$btnToggleLegal.Add_Click({
    $script:ShowLegal = !$script:ShowLegal
    &$UpdatePreview
})

$btnInfo.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Outlook Signature Editor v3.0`nAVL Deutschland GmbH`n`n2026", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# --- DARK MODE TOGGLE ---
$toggleBackground.Add_Click({
    $script:DarkMode = !$script:DarkMode
    
    if ($script:DarkMode) {
        $toggleButton.Location = [System.Drawing.Point]::new(38, 2)
        $toggleBackground.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        
        $form.BackColor = $script:Colors.DarkBg
        $sidebar.BackColor = $script:Colors.SidebarDark
        $inputContainer.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
        $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
        
        $preview.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
        $preview.ForeColor = [System.Drawing.Color]::White
        
        $lblMenu.ForeColor = [System.Drawing.Color]::White
        $lblLang.ForeColor = [System.Drawing.Color]::LightGray
        $lblCheckboxSection.ForeColor = [System.Drawing.Color]::LightGray
        $lblDarkModeSection.ForeColor = [System.Drawing.Color]::White
        
        $chkGreeting.ForeColor = [System.Drawing.Color]::White
        $chkDefault.ForeColor = [System.Drawing.Color]::White
        
        foreach ($control in $inputContainer.Controls) {
            if ($control -is [System.Windows.Forms.Label]) {
                $control.ForeColor = [System.Drawing.Color]::LightGray
            }
            if ($control -is [System.Windows.Forms.CheckBox]) {
                $control.ForeColor = [System.Drawing.Color]::White
            }
            if ($control -is [System.Windows.Forms.TextBox]) {
                $control.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
                $control.ForeColor = [System.Drawing.Color]::White
            }
        }
        
        $langBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
        $langBox.ForeColor = [System.Drawing.Color]::White
        
        $btnReset.BackColor = [System.Drawing.Color]::FromArgb(180, 80, 80)
        
    } else {
        $toggleButton.Location = [System.Drawing.Point]::new(2, 2)
        $toggleBackground.BackColor = [System.Drawing.Color]::LightGray
        
        $form.BackColor = $script:Colors.GrayBg
        $sidebar.BackColor = $script:Colors.SidebarGray
        $inputContainer.BackColor = $script:Colors.GrayBg
        $previewPanel.BackColor = $script:Colors.GrayBg
        
        $preview.BackColor = [System.Drawing.Color]::White
        $preview.ForeColor = [System.Drawing.Color]::Black
        
        $lblMenu.ForeColor = [System.Drawing.Color]::Black
        $lblLang.ForeColor = [System.Drawing.Color]::Gray
        $lblCheckboxSection.ForeColor = [System.Drawing.Color]::Gray
        $lblDarkModeSection.ForeColor = [System.Drawing.Color]::Gray
        
        $chkGreeting.ForeColor = [System.Drawing.Color]::Black
        $chkDefault.ForeColor = [System.Drawing.Color]::Black
        
        foreach ($control in $inputContainer.Controls) {
            if ($control -is [System.Windows.Forms.Label]) {
                $control.ForeColor = [System.Drawing.Color]::Gray
            }
            if ($control -is [System.Windows.Forms.CheckBox]) {
                $control.ForeColor = [System.Drawing.Color]::Black
            }
            if ($control -is [System.Windows.Forms.TextBox]) {
                $control.BackColor = [System.Drawing.Color]::White
                $control.ForeColor = [System.Drawing.Color]::Black
            }
        }
        
        $langBox.BackColor = [System.Drawing.Color]::White
        $langBox.ForeColor = [System.Drawing.Color]::Black
        
        $btnReset.BackColor = [System.Drawing.Color]::FromArgb(200, 100, 100)
    }
})

$langBox.Add_SelectedIndexChanged({ & $UpdatePreview })

& $UpdatePreview

$form.ShowDialog()
