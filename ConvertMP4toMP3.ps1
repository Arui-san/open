<#
.SYNOPSIS
    MP4 → MP3 変換 GUI ツール
.DESCRIPTION
    ffmpeg.exe（スクリプトと同じフォルダに配置）を利用し、
    MP4 ファイルを MP3 に変換する Windows Forms アプリケーション。
    PowerShell 5.1+ / Windows 10・11 標準環境で動作。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── アセンブリ読み込み ──
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ── ffmpeg パス解決 ──
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpeg    = Join-Path $scriptDir 'ffmpeg.exe'

if (-not (Test-Path $ffmpeg)) {
    [System.Windows.Forms.MessageBox]::Show(
        "ffmpeg.exe がスクリプトと同じフォルダに見つかりません。`n`n配置先: $scriptDir",
        'エラー',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# ── メインフォーム ──
$form            = New-Object System.Windows.Forms.Form
$form.Text       = 'MP4 → MP3 変換ツール'
$form.Size       = New-Object System.Drawing.Size(560, 420)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

# ── ファイルリスト (ListBox) ──
$labelFiles       = New-Object System.Windows.Forms.Label
$labelFiles.Text  = '変換対象ファイル:'
$labelFiles.Location = New-Object System.Drawing.Point(14, 12)
$labelFiles.AutoSize = $true
$form.Controls.Add($labelFiles)

$listBox          = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(14, 32)
$listBox.Size     = New-Object System.Drawing.Size(516, 180)
$listBox.HorizontalScrollbar = $true
$form.Controls.Add($listBox)

# ── ボタン: ファイルを選択 ──
$btnSelect          = New-Object System.Windows.Forms.Button
$btnSelect.Text     = 'ファイルを選択...'
$btnSelect.Location = New-Object System.Drawing.Point(14, 222)
$btnSelect.Size     = New-Object System.Drawing.Size(130, 30)
$form.Controls.Add($btnSelect)

# ── ボタン: リストをクリア ──
$btnClear          = New-Object System.Windows.Forms.Button
$btnClear.Text     = 'リストをクリア'
$btnClear.Location = New-Object System.Drawing.Point(154, 222)
$btnClear.Size     = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnClear)

# ── ボタン: 変換開始 ──
$btnConvert          = New-Object System.Windows.Forms.Button
$btnConvert.Text     = '変換開始'
$btnConvert.Location = New-Object System.Drawing.Point(400, 222)
$btnConvert.Size     = New-Object System.Drawing.Size(130, 30)
$form.Controls.Add($btnConvert)

# ── プログレスバー ──
$progressBar          = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(14, 264)
$progressBar.Size     = New-Object System.Drawing.Size(516, 22)
$progressBar.Minimum  = 0
$progressBar.Value    = 0
$form.Controls.Add($progressBar)

# ── ステータスラベル ──
$labelStatus          = New-Object System.Windows.Forms.Label
$labelStatus.Text     = '待機中'
$labelStatus.Location = New-Object System.Drawing.Point(14, 294)
$labelStatus.Size     = New-Object System.Drawing.Size(516, 20)
$form.Controls.Add($labelStatus)

# ── ログ表示 (TextBox) ──
$textLog            = New-Object System.Windows.Forms.TextBox
$textLog.Location   = New-Object System.Drawing.Point(14, 318)
$textLog.Size       = New-Object System.Drawing.Size(516, 55)
$textLog.Multiline  = $true
$textLog.ScrollBars = 'Vertical'
$textLog.ReadOnly   = $true
$textLog.Font       = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($textLog)

# ── ヘルパー: ログ追記 ──
function Write-Log {
    param([string]$Message)
    $textLog.AppendText("$Message`r`n")
}

# ── ファイル選択イベント ──
$btnSelect.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title       = 'MP4 ファイルを選択'
    $ofd.Filter      = 'MP4 ファイル (*.mp4)|*.mp4|すべてのファイル (*.*)|*.*'
    $ofd.Multiselect = $true

    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($f in $ofd.FileNames) {
            if (-not $listBox.Items.Contains($f)) {
                $listBox.Items.Add($f)
            }
        }
        $labelStatus.Text = "$($listBox.Items.Count) 件のファイルを選択中"
    }
})

# ── クリアイベント ──
$btnClear.Add_Click({
    $listBox.Items.Clear()
    $progressBar.Value = 0
    $labelStatus.Text  = '待機中'
    $textLog.Clear()
})

# ── 変換イベント ──
$btnConvert.Add_Click({
    if ($listBox.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            '変換するファイルを選択してください。',
            '情報',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    # UI をロック
    $btnSelect.Enabled  = $false
    $btnClear.Enabled   = $false
    $btnConvert.Enabled = $false

    $total     = $listBox.Items.Count
    $successCount = 0
    $failCount    = 0
    $progressBar.Maximum = $total
    $progressBar.Value   = 0
    $textLog.Clear()

    for ($i = 0; $i -lt $total; $i++) {
        $inputPath  = $listBox.Items[$i]
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, '.mp3')
        $fileName   = [System.IO.Path]::GetFileName($inputPath)

        $labelStatus.Text = "変換中 ($($i + 1) / $total): $fileName"
        [System.Windows.Forms.Application]::DoEvents()

        # 出力先が既に存在する場合は上書き確認
        if (Test-Path $outputPath) {
            $confirm = [System.Windows.Forms.MessageBox]::Show(
                "$([System.IO.Path]::GetFileName($outputPath)) は既に存在します。上書きしますか？",
                '上書き確認',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
                Write-Log "[スキップ] $fileName"
                $progressBar.Value = $i + 1
                continue
            }
        }

        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName               = $ffmpeg
            $psi.Arguments              = "-y -i `"$inputPath`" -vn -acodec libmp3lame -q:a 2 `"$outputPath`""
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            $psi.RedirectStandardError  = $true
            $psi.RedirectStandardOutput = $true

            $proc = [System.Diagnostics.Process]::Start($psi)

            # 定期的に DoEvents を呼び UI を応答可能に保つ
            while (-not $proc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 100
            }

            if ($proc.ExitCode -eq 0) {
                Write-Log "[成功] $fileName"
                $successCount++
            }
            else {
                $stderr = $proc.StandardError.ReadToEnd()
                Write-Log "[失敗] $fileName : $stderr"
                $failCount++
            }
        }
        catch {
            Write-Log "[エラー] $fileName : $($_.Exception.Message)"
            $failCount++
        }

        $progressBar.Value = $i + 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $labelStatus.Text = "完了 — 成功: $successCount / 失敗: $failCount"

    # UI ロック解除
    $btnSelect.Enabled  = $true
    $btnClear.Enabled   = $true
    $btnConvert.Enabled = $true

    [System.Windows.Forms.MessageBox]::Show(
        "変換が完了しました。`n成功: $successCount 件`n失敗: $failCount 件",
        '結果',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# ── 実行 ──
[void]$form.ShowDialog()
