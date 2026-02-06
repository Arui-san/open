# MP4 → MP3 変換ツール

PowerShell + Windows Forms で構成された、Windows 標準環境で動作する MP4 → MP3 変換 GUI ツールです。
`.bat` 形式なのでダブルクリックだけで起動できます。

## 動作要件

| 項目 | 要件 |
|------|------|
| OS | Windows 10 / 11 |
| PowerShell | 5.1 以上（OS 標準搭載） |
| 外部依存 | `ffmpeg.exe`（ポータブル版、インストール不要） |

## セットアップ手順

### 1. ffmpeg の入手

1. [https://www.gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/) にアクセスする
2. **release builds** セクションから `ffmpeg-release-essentials.zip` をダウンロードする
3. ZIP を展開し、`bin` フォルダ内の `ffmpeg.exe` を取り出す

### 2. ファイル配置

以下のように `ConvertMP4toMP3.bat` と `ffmpeg.exe` を **同じフォルダ** に配置します。

```
任意のフォルダ/
├── ConvertMP4toMP3.bat
└── ffmpeg.exe
```

### 3. 実行方法

`ConvertMP4toMP3.bat` をダブルクリックするだけで起動します。

## 使い方

1. 起動するとウィンドウが表示されます
2. **「ファイルを選択...」** ボタンで MP4 ファイルを選択（複数選択可）
3. **「変換開始」** ボタンをクリック
4. 変換された MP3 ファイルは元の MP4 と同じフォルダに保存されます

## 変換仕様

- コーデック: `libmp3lame`
- 品質: `-q:a 2`（VBR、約 170–210 kbps 相当）
- 映像トラックは除去（`-vn`）
- 出力ファイル名: 元のファイル名の拡張子を `.mp3` に変更
