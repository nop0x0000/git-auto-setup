$gitFolder = '~/AppData/Local/Git/'
$gitTemplateFolder = 'git_template'
$gitMsgFile = 'gitMsgForNotepad.txt'
$gitCompletionFile = 'git-flow-completion.bash'

$gitTemplateFolderPath = $gitFolder + $gitTemplateFolder
$gitMsgFilePath = $gitFolder + $gitMsgFile
$gitCompletionFilePath = $gitFolder + $gitCompletionFile

# メールアドレスを入力してもらう
do {
    $email = Read-Host "メールアドレスを入力してください(Enterで確定)"
} while (-not ($email -match "^([^@]+)@.+$"))
$name = $Matches[1] # メールアドレスの@より前をデフォルトの名前としてひとまず設定

# 名前を入力してもらう
while ($True) {
    $nameSpecified = Read-Host "名前を入力してください(デフォルト: $name)"
    if ([bool]$nameSpecified) {
        $name = $nameSpecified
    }
    if ((Read-Host "名前は $name で良いですか? (y/n)") -eq 'y') {
        break
    }
}

# GitとChocolatey がインストールされているかどうかチェック
Get-Command git -ea SilentlyContinue | Out-Null
$isGitInstalled = $?
Get-Command choco -ea SilentlyContinue | Out-Null
$isChocolateyInstalled = $?

# GitがインストールされいなければChocolatey経由でGitをインストール
if (-not $isGitInstalled) {
    if (-not $isChocolateyInstalled) {
        # Chocolateyのインストール
        Write-Output "Chocolateyをインストール中"
        Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    # Gitのインストール
    Write-Output "Gitをインストール中"
    choco install git -y
    # 環境変数を再読込
    # 参考 : https://codeday.me/jp/qa/20181207/61972.html
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Gitの初期設定
Write-Output "Gitの初期設定中"
git config --global user.name $name
git config --global user.email "$email"
git config --global push.default current
git config --global core.autoCRLF false
git config --global core.quotepath false
git config --global --add merge.ff false
git config --global --add pull.ff only
git config --global color.diff auto
git config --global color.status auto
git config --global color.branch auto

# Git用フォルダを作成
New-Item -Path $gitFolder -ItemType Directory -Force | Out-Null

# コミットメッセージ入力にメモ帳を使用する(文字化け回避)
# 参考 : https://qiita.com/Tachy_Pochy/items/b8e475c7cfd25b2b48bd
Write-Output "コミットメッセージ編集をメモ帳でできるよう設定中"
$commitComment = "`n# 変更内容についてのコミットメッセージをここに記述してください。`n# 行頭に '#' の記号が書かれている場合、その行は無視されます。`n# メッセージが空のままなら、コミットを中止します。"
New-Item -Path $gitMsgFilePath -ItemType File -Force | Out-Null
Start-Sleep -Seconds 1 # ファイルが作成されるのを待つ
# UTF-8(BOM無し)でテキストファイルを保存
# 参考 : https://blog.shibata.tech/entry/2016/10/02/154329
$UTF8woBOM = New-Object "System.Text.UTF8Encoding" -ArgumentList @($false)
[System.IO.File]::WriteAllLines((Convert-Path -Path $gitMsgFilePath), @($commitComment), $UTF8woBOM)
git config --global core.editor notepad
git config --global commit.template $gitMsgFilePath

# Template用フォルダを作成
New-Item -Path $gitTemplateFolderPath -ItemType Directory -Force | Out-Null

# テンプレートhooksファイルを設定する
Write-Output "hooksファイルを設定中"
$previousLocation = Get-Location
Set-Location $gitTemplateFolderPath
git clone "https://github.com/nop0x0000/git-hook.git" "hooks"
Set-Location $previousLocation
git config --global init.templatedir ($gitTemplateFolderPath)

# git-flow-completion.bash をインストールする
Write-Output "Git-Flow-Completionをインストール中"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/bobthecow/git-flow-completion/master/git-flow-completion.bash  -OutFile "~/AppData/Local/Git/git-flow-completion.bash"
if (Test-Path -Path "~/.bashrc") {
    Get-Content "~/.bashrc" | Where-Object {$_ -notmatch "^source.*git-flow-completion.bash.*$"} | Out-File "~/.bashrc" # 古い設定を削除
}
Add-Content -Path "~/.bashrc" -Value ("source " + ($gitCompletionFilePath -replace "\\","/")) -Encoding ASCII # 新しい設定を追加

# git log の文字化け回避
Write-Output "git log の文字化け回避の設定中"
# 参考 : https://qiita.com/Tachibana446/items/b6a869afa9959581dfc0
[System.Environment]::SetEnvironmentVariable('LESSCHARSET', 'utf-8', 'User')

# 完了メッセージ出力
Write-Host "Complete installation."

Pause