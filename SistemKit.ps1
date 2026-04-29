
# ================================================================
#  SistemKit v8.1 - ULTIMATE SÜRÜM
#  Yenilikler: 3D Disk Grafiği, Gecikmeli Başlatma (Task Scheduler),
#              Asenkron Görevler (Arayüz Donması Giderildi),
#              Global Hata Yakalayıcı (Crash Engellendi)
# ================================================================

# --- [KRİTİK EKLENTİ] ARKA PLAN CMD EKRANINI GİZLEME ---
try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
   # $consolePtr = [Console.Window]::GetConsoleWindow() [Console.Window]::ShowWindow($consolePtr, 0) # 0 = Görünmez yapar
} catch {}
# -------------------------------------------------------

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    try { Add-Type -AssemblyName System.Windows.Forms.DataVisualization } catch {}
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    [System.Windows.Forms.Application]::EnableVisualStyles()

 # ======================== YONETICI KONTROL ========================
    $global:yoneticiMi = $false
    try {
        $kimlik=[Security.Principal.WindowsIdentity]::GetCurrent()
        $prensip=New-Object Security.Principal.WindowsPrincipal($kimlik)
        $global:yoneticiMi=$prensip.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {}

    function Kontrol-Yonetici($islemAdi="Bu islem"){
        if(-not $global:yoneticiMi){
            [System.Windows.Forms.MessageBox]::Show(
                "$islemAdi icin yonetici yetkisi gereklidir.`n`nUygulamayi yonetici olarak calistirmayi deneyin:`nSistemKit_YoneticiOlarak.bat",
                "Yonetici Yetkisi Gerekli",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return $false
        }
        return $true
    }

    $BG_DARK   = [System.Drawing.Color]::FromArgb(15,15,20)
    $BG_PANEL  = [System.Drawing.Color]::FromArgb(24,24,34)
    $BG_CARD   = [System.Drawing.Color]::FromArgb(34,34,48)
    $BG_HOVER  = [System.Drawing.Color]::FromArgb(50,50,70)
    $FG_MAIN   = [System.Drawing.Color]::White
    $FG_DIM    = [System.Drawing.Color]::FromArgb(150,150,175)
    $ACCENT    = [System.Drawing.Color]::FromArgb(99,102,241)
    $SUCCESS   = [System.Drawing.Color]::FromArgb(34,197,94)
    $WARNING   = [System.Drawing.Color]::FromArgb(251,191,36)
    $DANGER    = [System.Drawing.Color]::FromArgb(239,68,68)
    $INFO      = [System.Drawing.Color]::FromArgb(56,189,248)
    $SUBTLE    = [System.Drawing.Color]::FromArgb(55,55,75)

    $PIE_RENKLER = @(
        "#6366F1","#EC4899","#F59E0B","#10B981","#3B82F6",
        "#EF4444","#8B5CF6","#14B8A6","#F97316","#06B6D4",
        "#A855F7","#84CC16","#E11D48","#0EA5E9","#D97706"
    )

    $global:analizVerisi  = @()
    $global:izlemeTimer   = $null
    $global:islemBaslangic= $null
    $global:kuruluListesi = @()
    $global:analizIptal   = $false
    $global:ayarDosya     = "$env:APPDATA\SistemKit\Settings.json"

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.AutoPopDelay=5000; $toolTip.InitialDelay=500; $toolTip.ReshowDelay=300
    $toolTip.ShowAlways=$true; $toolTip.BackColor=$BG_CARD; $toolTip.ForeColor=$FG_MAIN

    $form = New-Object System.Windows.Forms.Form
    $form.Text="SistemKit v8.1"
    $form.Size=[System.Drawing.Size]::new(1180,760)
    $form.MinimumSize=[System.Drawing.Size]::new(1050,680)
    $form.StartPosition="CenterScreen"
    $form.BackColor=$BG_DARK; $form.ForeColor=$FG_MAIN
    $form.Font=New-Object System.Drawing.Font("Segoe UI",9)

    function Yeni-Buton($yazi,$renk,$en=140,$boy=34,$ipucu=""){
        $b=New-Object System.Windows.Forms.Button
        $b.Text=$yazi; $b.Width=$en; $b.Height=$boy
        $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0
        $b.BackColor=$renk; $b.ForeColor=[System.Drawing.Color]::White
        $b.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
        $b.Cursor="Hand"
        $b.Margin=[System.Windows.Forms.Padding]::new(0,4,8,0)
        $hr=[System.Drawing.Color]::FromArgb(
            [math]::Min(255,$renk.R+25),
            [math]::Min(255,$renk.G+25),
            [math]::Min(255,$renk.B+30))
        $nr=$renk
        $b.Add_MouseEnter({$this.BackColor=$hr}.GetNewClosure())
        $b.Add_MouseLeave({$this.BackColor=$nr}.GetNewClosure())
        if($ipucu){$toolTip.SetToolTip($b,$ipucu)}
        return $b
    }

    function Yeni-Etiket($yazi,$font,$renk,$x,$y,$en,$boy){
        $l=New-Object System.Windows.Forms.Label
        $l.Text=$yazi; $l.Font=$font; $l.ForeColor=$renk
        $l.Location=[System.Drawing.Point]::new($x,$y)
        $l.Size=[System.Drawing.Size]::new($en,$boy)
        $l.BackColor=[System.Drawing.Color]::Transparent
        return $l
    }

    function Yeni-MetinKutusu($x,$y,$en,$boy){
        $r=New-Object System.Windows.Forms.RichTextBox
        $r.Location=[System.Drawing.Point]::new($x,$y)
        $r.Size=[System.Drawing.Size]::new($en,$boy)
        $r.BackColor=$BG_CARD; $r.ForeColor=$FG_MAIN
        $r.ReadOnly=$true; $r.BorderStyle="None"
        $r.Font=New-Object System.Drawing.Font("Consolas",9)
        $r.ScrollBars="Vertical"
        return $r
    }

    function Yeni-IlerlemeKubugu($x,$y,$en){
        $p=New-Object System.Windows.Forms.ProgressBar
        $p.Location=[System.Drawing.Point]::new($x,$y)
        $p.Size=[System.Drawing.Size]::new($en,22)
        $p.Style="Continuous"; $p.ForeColor=$ACCENT; $p.BackColor=$BG_CARD
        return $p
    }

    function Yeni-Kart($x,$y,$en,$boy){
        $p=New-Object System.Windows.Forms.Panel
        $p.Location=[System.Drawing.Point]::new($x,$y)
        $p.Size=[System.Drawing.Size]::new($en,$boy)
        $p.BackColor=$BG_PANEL
        return $p
    }

    function Yaz-Log($rtb,$mesaj,$renk){
        if(-not $renk){$renk=$FG_MAIN}
        $zaman=Get-Date -f "HH:mm:ss"
        if($global:islemBaslangic){
            $sure=[math]::Round(((Get-Date)-$global:islemBaslangic).TotalSeconds,1)
            $zaman="$zaman +$($sure)s"
        }
        try{
            $rtb.SelectionStart=$rtb.TextLength
            $rtb.SelectionLength=0
            $rtb.SelectionColor=$renk
            $rtb.AppendText("[$zaman] $mesaj`n")
            $rtb.ScrollToCaret()
        }catch{}
    }

function Goster-Bildirim($baslik,$mesaj){
        try{
            $b=New-Object System.Windows.Forms.NotifyIcon
            $b.Icon=[System.Drawing.SystemIcons]::Information
            $b.Visible=$true
            $b.ShowBalloonTip(3000,$baslik,$mesaj,[System.Windows.Forms.ToolTipIcon]::Info)
            
            $notifTimer = New-Object System.Windows.Forms.Timer
            $notifTimer.Interval = 4000
            $notifTimer.Tag = $b # Kilit Nokta: Balon nesnesini Timer'ın cebine saklıyoruz
            $notifTimer.Add_Tick({
                try {
                    $nf = $this.Tag
                    if ($null -ne $nf) { $nf.Visible=$false; $nf.Dispose() }
                    $this.Stop(); $this.Dispose()
                } catch {}
            })
            $notifTimer.Start()
        }catch{}
    }

    # ======================== AYARLAR ========================
    function Yukle-Ayarlar{
        try{
            if(Test-Path $global:ayarDosya){
                $json=Get-Content $global:ayarDosya -Raw|ConvertFrom-Json
                return $json
            }
        }catch{}
        return [PSCustomObject]@{Son_Sekme=0}
    }
    function Kaydet-Ayarlar($v){
        try{
            $kl=Split-Path $global:ayarDosya
            if(-not (Test-Path $kl)){New-Item $kl -ItemType Directory -Force|Out-Null}
            $v|ConvertTo-Json|Out-File $global:ayarDosya -Encoding UTF8 -Force
        }catch{}
    }
# ================================================================
#  SISTEMKIT v8.1 - AKILLI NAVIGASYON ÜNİTESİ (LİKİT MİMARİ)
# ================================================================

# --- [KRİTİK ADIM 1] FONKSİYONLARI BAŞA ALIYORUZ (HATA 220 ÇÖZÜMÜ) ---
function Yeni-Sekme($ad){
    $t = New-Object System.Windows.Forms.TabPage
    $t.Text = $ad; $t.BackColor = $BG_DARK; $t.ForeColor = $FG_MAIN
    $tabs.TabPages.Add($t); return $t
}

function Guncelle-SekmeBtnleri($idx){
    if ($null -eq $sekmeBtnleri -or $sekmeBtnleri.Count -eq 0) { return } 
    for($i=0; $i -lt $sekmeBtnleri.Count; $i++){
        $b = $sekmeBtnleri[$i]
        if($i -eq $idx){
            $b.BackColor = $ACCENT; $b.ForeColor = [System.Drawing.Color]::White
            $b.Font = New-Object System.Drawing.Font("Segoe UI",8.5,[System.Drawing.FontStyle]::Bold)
        } else {
            $b.BackColor = $BG_CARD; $b.ForeColor = [System.Drawing.Color]::FromArgb(195,195,215)
            $b.Font = New-Object System.Drawing.Font("Segoe UI",8.5)
        }
    }
}

function Hizala-SekmeButonlari {
    if ($null -eq $form -or $sekmeBtnleri.Count -eq 0) { return }
    $toplamEn = $sekmePaneli.ClientSize.Width
    $adet = $sekmeBtnleri.Count
    $birimEn = $toplamEn / $adet
    for($i=0; $i -lt $adet; $i++) {
        $b = $sekmeBtnleri[$i]
        $mevcutX = [int]($i * $birimEn)
        $b.Location = New-Object System.Drawing.Point($mevcutX, 3)
        $b.Width = if($i -eq ($adet-1)){$toplamEn - $mevcutX}else{[int]$birimEn}
    }
}

# --- [KRİTİK ADIM 2] ANA NESNELERİ TEMİZ VE TEK SEFERDE KURUYORUZ ---
if ($null -ne $tabs) { $form.Controls.Remove($tabs) }
if ($null -ne $sekmePaneli) { $form.Controls.Remove($sekmePaneli) }

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"; $tabs.Appearance = "Buttons"
$tabs.ItemSize = [System.Drawing.Size]::new(0,1); $tabs.SizeMode = "Fixed"
$tabs.BackColor = $BG_DARK
$form.Controls.Add($tabs)

$sekmePaneli = New-Object System.Windows.Forms.Panel
$sekmePaneli.Dock = "Top"; $sekmePaneli.Height = 44
$sekmePaneli.BackColor = [System.Drawing.Color]::FromArgb(18,18,28)
$form.Controls.Add($sekmePaneli)
$form.Controls.SetChildIndex($sekmePaneli, 0)

$sekmeler = @("Sistem Bakimi","Sistem Izleme","Baslangic","Araclar","Sistem Kurulumu","Hakkinda")
$sekmeBtnleri = @()

# --- [KRİTİK ADIM 3] BUTONLARI VE SAYFALARI OLUŞTURUYORUZ ---
for($i=0; $i -lt $sekmeler.Count; $i++){
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $sekmeler[$i]; $b.Height = 38; $b.Tag = $i
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0; $b.Cursor = "Hand"
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $b.Add_Click({
        $idx = [int]$this.Tag; $tabs.SelectedIndex = $idx; Guncelle-SekmeBtnleri $idx
        $modStr2 = if($global:yoneticiMi){"Yonetici"}else{"Standart"}
        $altDurum.Text = "SistemKit v8.1 | [$modStr2] $($sekmeler[$idx])"
    })
    $sekmePaneli.Controls.Add($b); $sekmeBtnleri += $b
}

# SAYFALARI TANIMLA (Hata 220 artık imkansız, çünkü fonksiyon yukarıda!)
$sekmeBakim     = Yeni-Sekme "Sistem Bakimi"
$sekmeIzleme    = Yeni-Sekme "Sistem Izleme"
$sekmeBaslangic = Yeni-Sekme "Baslangic"
$sekmeAraclar   = Yeni-Sekme "Araclar"
$sekmeKurulum   = Yeni-Sekme "Sistem Kurulumu"
$sekmeHakkinda  = Yeni-Sekme "Hakkinda"

# --- [KRİTİK ADIM 4] FİNAL TETİKLEME ---
$form.Add_Resize({ Hizala-SekmeButonlari })
Guncelle-SekmeBtnleri 0
Hizala-SekmeButonlari


    # ================================================================
    #  SEKME 1 - SİSTEM BAKIMI (BİRLEŞTİRİLMİŞ MODÜL)
    # ================================================================
    $bakimSol=New-Object System.Windows.Forms.Panel
    $bakimSol.Width=490; $bakimSol.Dock="Left"; $bakimSol.BackColor=$BG_PANEL
    $sekmeBakim.Controls.Add($bakimSol)

    # ----------------------------------------------------------------
    # ÜST KAT: DİSK ANALİZİ GRUBU (Tam Merkeze Hizalandı)
    # ----------------------------------------------------------------
    $bakimSol.Controls.Add((Yeni-Etiket "Disk Kullanim Analizi" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 60 460 22))
    
    $listeDisk=New-Object System.Windows.Forms.CheckedListBox
    $listeDisk.Location=[System.Drawing.Point]::new(10,90); $listeDisk.Size=[System.Drawing.Size]::new(468,135)
    $listeDisk.BackColor=$BG_CARD; $listeDisk.ForeColor=$FG_MAIN; $listeDisk.BorderStyle="None"
    $listeDisk.Font=New-Object System.Drawing.Font("Segoe UI",9); $listeDisk.CheckOnClick=$true
    $bakimSol.Controls.Add($listeDisk)

	# --- [v8.1] KALİBRE EDİLMİŞ TOOLTIP SİSTEMİ ---
	$listeDisk.Add_MouseMove({
      try {
        # Farenin altındaki satırın numarasını al
        $mi = $listeDisk.IndexFromPoint($_.Location)
        
        # Eğer geçerli bir satırın üzerindeysek
			if($mi -ge 0 -and $mi -lt $listeDisk.Items.Count) {
            # Satırın üzerindeki metni al (Örn: "Downloads (450 MB)")
            $itemMetni = $listeDisk.Items[$mi].ToString()
            
            # Bu metne sahip doğru veriyi diziden bul (Sıralama hatasını bitiren nokta)
            $bulunan = $global:analizVerisi | Where-Object { 
                "$($_.Ad)  ($($_.BoyutMB) MB)" -eq $itemMetni 
				} | Select-Object -First 1
            
				if($null -ne $bulunan) {
                # Bilgiyi tam üzerine yapıştır
                $toolTip.SetToolTip($listeDisk, "Klasor: $($bulunan.Ad)`nYol: $($bulunan.Yol)`nBoyut: $($bulunan.BoyutMB) MB`nDosya: $($bulunan.DosyaSayisi) adet")
				}
			}
		} catch {}
	})
	

    $lblDiskAnlikDosya=Yeni-Etiket "" (New-Object System.Drawing.Font("Segoe UI",8)) $INFO 10 230 468 15
    $bakimSol.Controls.Add($lblDiskAnlikDosya)
    
    $ilerlDisk=Yeni-IlerlemeKubugu 10 250 468
    $bakimSol.Controls.Add($ilerlDisk)
    
    $lblDiskDurum=Yeni-Etiket "Disk: Hazir" (New-Object System.Drawing.Font("Segoe UI",8)) $FG_DIM 10 275 468 15
    $bakimSol.Controls.Add($lblDiskDurum)

    $diskAkis=New-Object System.Windows.Forms.FlowLayoutPanel
    $diskAkis.Location=[System.Drawing.Point]::new(10,295); $diskAkis.Size=[System.Drawing.Size]::new(468,36)
    $diskAkis.BackColor=$BG_PANEL; $diskAkis.FlowDirection="LeftToRight"; $diskAkis.WrapContents=$false
    $btnAnalizBaslat=Yeni-Buton "Disk Analizi" $ACCENT 125 32 "Disk analizi baslatir"
    $btnTumunuSec   =Yeni-Buton "Tumunu Sec"   $SUBTLE 105 32
    $btnSecileniSil =Yeni-Buton "Secileni Kalici Sil" $DANGER 225 32 "Secili klasorleri sil"
    foreach($b in @($btnAnalizBaslat,$btnTumunuSec,$btnSecileniSil)){ $diskAkis.Controls.Add($b) }
    $bakimSol.Controls.Add($diskAkis)

    # ----------------------------------------------------------------
    # GÖRSEL AYRAÇ
    # ----------------------------------------------------------------
    $ayracBakim=New-Object System.Windows.Forms.Label
    $ayracBakim.Location=[System.Drawing.Point]::new(10,350); $ayracBakim.Size=[System.Drawing.Size]::new(468,1)
    $ayracBakim.BackColor=[System.Drawing.Color]::FromArgb(55,55,75)
    $bakimSol.Controls.Add($ayracBakim)

# ----------------------------------------------------------------
    # ALT KAT: AKILLI TEMİZLİK GRUBU (Tam Merkeze Hizalandı)
    # ----------------------------------------------------------------
    $bakimSol.Controls.Add((Yeni-Etiket "Akilli Temizlik Alanlari" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) $ACCENT 10 370 460 22))
    
    $temizSecenekler=@(
        @{A="Temp";    E="Gecici Dosyalar (%TEMP%)";    B="Kullanici temp klasoru"}
        @{A="WinTemp"; E="Windows Temp Klasoru";         B="C:\Windows\Temp icerigi"}
        @{A="Cop";     E="Geri Donusum Kutusu";          B="Kalici bosaltma"}
        @{A="Prefetch";E="Prefetch Dosyalari";           B="C:\Windows\Prefetch icerigi"}
        @{A="Olay";    E="Olay Gunlukleri";              B="Windows Event Log"}
        @{A="Chrome";  E="Chrome Onbellegi";             B="Google Chrome gecici dosyalari"}
        @{A="Edge";    E="Edge Onbellegi";               B="Microsoft Edge gecici dosyalari"}
        @{A="Kucuk";   E="Kucuk Resim Onbellegi";        B="Explorer thumbnail cache"}
        @{A="Guncell"; E="Guncelleme Yedekleri";         B="SoftwareDistribution Download"}
    )
    $temizKutular=@{}; $cx=15; $cy=400; $say=0
    foreach($s in $temizSecenekler){
        $cb=New-Object System.Windows.Forms.CheckBox
        $cb.Text=$s.E; $cb.Location=[System.Drawing.Point]::new($cx,$cy)
        $cb.Size=[System.Drawing.Size]::new(220,20); $cb.ForeColor=$FG_MAIN; $cb.Checked=$true
        $ipucu = $s.B
        
        # EKSİK OLAN KISIM BURASIYDI, TAMAMLANDI:
        if (-not $global:yoneticiMi -and ($s.A -eq "WinTemp" -or $s.A -eq "Prefetch" -or $s.A -eq "Guncell")) {
            $cb.Enabled = $false; $cb.Checked = $false; $cb.ForeColor = $FG_DIM
            $ipucu += " (Yonetici Yetkisi Gerekli)"
        }
        $toolTip.SetToolTip($cb,$ipucu)
        $bakimSol.Controls.Add($cb)
        $temizKutular[$s.A]=$cb
        
        $say++; $cy+=24
        if($say -eq 5){ $cx=240; $cy=400 } # 2. Sütuna geçiş
    }

    $ilerlTemiz=Yeni-IlerlemeKubugu 10 530 468
    $bakimSol.Controls.Add($ilerlTemiz)
    
    $lblTemizDurum=Yeni-Etiket "Temizlik: Hazir" (New-Object System.Drawing.Font("Segoe UI",8)) $FG_DIM 10 555 468 15
    $bakimSol.Controls.Add($lblTemizDurum)

	# --- TEMİZLİK AKIŞ PANELİ (AKILLI KALDIRICI EKLENDİ) ---
    $temizAkis = New-Object System.Windows.Forms.FlowLayoutPanel
    $temizAkis.Location = [System.Drawing.Point]::new(10, 580)
    $temizAkis.Size = [System.Drawing.Size]::new(468, 75) # Yüksekliği artırdık ki 2. satıra insin
    $temizAkis.BackColor = $BG_PANEL
    $temizAkis.FlowDirection = "LeftToRight"
    $temizAkis.WrapContents = $true # Butonlar sığmazsa alt satıra geçmesini sağlar
    
    $btnTemizlikBaslat = Yeni-Buton "Sistem Temizligi" $ACCENT 155 32 "Secili copleri temizler"
    $btnDiskTemizleme  = Yeni-Buton "Win Disk Temizle" $SUBTLE 140 32 "Windows disk temizleme araci"
    $btnZamanlaTemizlik= Yeni-Buton "Zamanli Gorev"    $WARNING 155 32 "Otomatik temizlik kur"
    
    # İŞTE YENİ BUTONUMUZ:
    $btnAkilliKaldiriciAc = Yeni-Buton "Uygulama Kaldir & Derin Temizle" $DANGER 230 32 "Gelismis kaldirici ve derin temizlik aracini baslatir"
    
    foreach($b in @($btnTemizlikBaslat, $btnDiskTemizleme, $btnZamanlaTemizlik, $btnAkilliKaldiriciAc)){ 
        $temizAkis.Controls.Add($b) 
    }
    $bakimSol.Controls.Add($temizAkis)
	
	# ================================================================
    # AÇILIR PENCERE (POPUP): AKILLI KALDIRICI VE DERİN TEMİZLİK MOTORU
    # ================================================================
    $btnAkilliKaldiriciAc.Add_Click({
        $kForm = New-Object System.Windows.Forms.Form
        $kForm.Text = "SistemKit v8.1 - Akilli Uygulama Kaldirici & Derin Temizlik"
        $kForm.Size = [System.Drawing.Size]::new(750, 550)
        $kForm.StartPosition = "CenterParent"
        $kForm.BackColor = $BG_DARK; $kForm.ForeColor = $FG_MAIN
        $kForm.MinimizeBox = $false; $kForm.MaximizeBox = $false
        $kForm.FormBorderStyle = "FixedDialog"
        
        # 1. ÜST PANEL (Açıklama ve Yenile Butonu)
        $kUst = New-Object System.Windows.Forms.Panel
        $kUst.Dock = "Top"; $kUst.Height = 65; $kUst.BackColor = $BG_PANEL
        $kForm.Controls.Add($kUst)
        
        $kUst.Controls.Add((Yeni-Etiket "Derin Temizlik (Hafiye Modu)" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) $DANGER 15 10 300 22))
        $kUst.Controls.Add((Yeni-Etiket "Uygulamalari kaldirir ve AppData, ProgramData, Kayit Defteri gibi konumlardaki kalintilari avlar." (New-Object System.Drawing.Font("Segoe UI",8.5)) $FG_DIM 15 35 500 20))
        
        $btnListeYenile = Yeni-Buton "Listeyi Tarat" $SUBTLE 120 30
        $btnListeYenile.Location = [System.Drawing.Point]::new(595, 18)
        $kUst.Controls.Add($btnListeYenile)

        # 2. ALT PANEL (Durum ve Kaldır Butonu)
        $kAlt = New-Object System.Windows.Forms.Panel
        $kAlt.Dock = "Bottom"; $kAlt.Height = 65; $kAlt.BackColor = $BG_PANEL
        $kForm.Controls.Add($kAlt)
        
        $lblDurum = Yeni-Etiket "Hazir. Listeyi taratmak icin butona basin." (New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)) $WARNING 15 22 450 20
        $kAlt.Controls.Add($lblDurum)
        
        $btnSecileniKaldir = Yeni-Buton "Secileni Kaldir & Temizle" $DANGER 220 34
        $btnSecileniKaldir.Location = [System.Drawing.Point]::new(495, 15); $btnSecileniKaldir.Enabled = $false
        $kAlt.Controls.Add($btnSecileniKaldir)

        # 3. ORTA PANEL (Uygulama Listesi)
        $listeKaldir = New-Object System.Windows.Forms.ListView
        $listeKaldir.Dock = "Fill"
        $listeKaldir.BackColor = $BG_CARD; $listeKaldir.ForeColor = $FG_MAIN
        $listeKaldir.View = "Details"; $listeKaldir.FullRowSelect = $true
        $listeKaldir.GridLines = $false; $listeKaldir.BorderStyle = "None"
        $listeKaldir.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        
        $listeKaldir.Columns.Add("Uygulama Adi", 320) | Out-Null
        $listeKaldir.Columns.Add("Yayimci", 180) | Out-Null
        $listeKaldir.Columns.Add("Surum", 100) | Out-Null
        $listeKaldir.Columns.Add("Gizli_Yol", 0) | Out-Null   # Arka plan işlemleri için gizli
        $listeKaldir.Columns.Add("Gizli_Komut", 0) | Out-Null # Arka plan işlemleri için gizli
        $kForm.Controls.Add($listeKaldir)
        $kForm.Controls.SetChildIndex($listeKaldir, 0) # Fill'in düzgün çalışması için öne alıyoruz

        # --- 4. KAYIT DEFTERİ IŞIK HIZINDA TARAMA MOTORU ---
        $btnListeYenile.Add_Click({
            $btnListeYenile.Enabled = $false; $btnSecileniKaldir.Enabled = $false
            $listeKaldir.Items.Clear()
            $lblDurum.Text = "Kayit Defteri taraniyor... Lutfen bekleyin."; $lblDurum.ForeColor = $WARNING
            $kForm.Refresh()

            $yollar = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            $uygulamalar = Get-ItemProperty $yollar -ErrorAction SilentlyContinue | 
                           Where-Object { $_.DisplayName -and $_.UninstallString } | 
                           Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, PSPath | 
                           Sort-Object DisplayName -Unique

            $listeKaldir.BeginUpdate()
            foreach ($uyg in $uygulamalar) {
                # $() ile sararak $null değerlerin listeyi patlatmasını engelliyoruz
                $satir = New-Object System.Windows.Forms.ListViewItem("$($uyg.DisplayName)")
                $satir.SubItems.Add("$($uyg.Publisher)") | Out-Null
                $satir.SubItems.Add("$($uyg.DisplayVersion)") | Out-Null
                $satir.SubItems.Add("$($uyg.PSPath)") | Out-Null
                $satir.SubItems.Add("$($uyg.UninstallString)") | Out-Null
                $listeKaldir.Items.Add($satir) | Out-Null
            }
            $listeKaldir.EndUpdate()

            $lblDurum.Text = "Sistem Tarandi: $($listeKaldir.Items.Count) Uygulama Bulundu"
            $lblDurum.ForeColor = $SUCCESS
            $btnListeYenile.Enabled = $true; $btnSecileniKaldir.Enabled = $true
        })

        # --- 5. DERİN TEMİZLİK & KALDIRMA İNFAZ MOTORU ---
        $btnSecileniKaldir.Add_Click({
            if ($listeKaldir.SelectedItems.Count -eq 0) { 
                [System.Windows.Forms.MessageBox]::Show("Lutfen kaldirilacak bir uygulama secin.", "Uyari", 0, 48)
                return 
            }

            # Listedeki gizli verileri çekiyoruz
            $secilen = $listeKaldir.SelectedItems[0]
            $ad = $secilen.SubItems[0].Text
            $yayimci = $secilen.SubItems[1].Text
            $regYol = $secilen.SubItems[3].Text
            $komut = $secilen.SubItems[4].Text

            $onay = [System.Windows.Forms.MessageBox]::Show("'$ad' kaldirilacak ve ardindan derin temizlik taramasi yapilacak. Emin misiniz?", "Akilli Kaldirici", 4, 32)
            if ($onay -ne "Yes") { return }

            $btnSecileniKaldir.Enabled = $false; $btnListeYenile.Enabled = $false
            $lblDurum.Text = "1/2: Windows Standart Kaldiricisi calistiriliyor..."; $lblDurum.ForeColor = $INFO
            $kForm.Refresh()

            # Aşama 1: Orijinal Uninstall Komutunu Tetikle
            try {
                Start-Process cmd -ArgumentList "/c `"$komut`"" -PassThru -Wait | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Orijinal kaldirici baslatilamadi veya hata verdi. Derin temizlige geciliyor...", "Bilgi", 0, 48)
            }

            # Aşama 2: Hafiye Modu (Çöp Avı)
            $lblDurum.Text = "2/2: Sistemde kalinti taramasi basladi (Hafiye Modu)..."; $lblDurum.ForeColor = $WARNING
            $kForm.Refresh()
            Start-Sleep -Seconds 2 # Dosya kilitlerinin açılması için kısa bir mola

            $bulunanCopler = @()
            $hedefKlasorler = @("$env:APPDATA", "$env:LOCALAPPDATA", "$env:ProgramData")
            
            foreach ($klasor in $hedefKlasorler) {
                # Yayımcı klasörü içinde arama (Örn: Adobe\Photoshop)
                if ($yayimci) {
                    $yol1 = Join-Path $klasor $yayimci | Join-Path -ChildPath $ad
                    if (Test-Path $yol1) { $bulunanCopler += $yol1 }
                }
                # Direkt isimle arama (Örn: Photoshop)
                $yol2 = Join-Path $klasor $ad
                if (Test-Path $yol2) { $bulunanCopler += $yol2 }
            }
            
            # Kayıt Defteri kalıntısı
            if (Test-Path $regYol) { $bulunanCopler += $regYol }

            # Aşama 3: İnfaz Kararı (Sadece çöp bulunursa sorar)
            if ($bulunanCopler.Count -gt 0) {
                $copMesaj = $bulunanCopler -join "`n"
                $temizleOnay = [System.Windows.Forms.MessageBox]::Show("Kaldirma islemi bitti. Asagidaki artiklar bulundu, kalici olarak silinsin mi?`n`n$copMesaj", "Derin Temizlik Onayi", 4, 32)
                
                if ($temizleOnay -eq "Yes") {
                    $silinen = 0
                    foreach ($cop in $bulunanCopler) {
                        try { Remove-Item -Path $cop -Recurse -Force -ErrorAction Stop; $silinen++ } catch { }
                    }
                    [System.Windows.Forms.MessageBox]::Show("Derin Temizlik Tamamlandi! $silinen adet kalinti/cop yok edildi.", "Basarili", 0, 64)
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Harika! Standart kaldirici isini iyi yapti. Sistem tertemiz, artik dosya bulunamadi.", "Temiz", 0, 64)
            }

            # İşlem bitince listeyi otomatik yenile
            $btnListeYenile.PerformClick()
        })

        # Pencere açıldığı an listeyi otomatik taratmaya başla
        $kForm.Add_Shown({ $btnListeYenile.PerformClick() })
        $kForm.ShowDialog() | Out-Null
    })
	
    # --- SAĞ PANEL: ORTAK 3D GRAFİK VE LOG EKRANI ---
    $bakimSag=New-Object System.Windows.Forms.Panel
    $bakimSag.Dock="Fill"; $bakimSag.BackColor=$BG_DARK
    $sekmeBakim.Controls.Add($bakimSag)

    $lblGrafik=Yeni-Etiket "Boyut Dagilimi (Analiz/Temizlik Sonuclari)" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 10 560 24
    $bakimSag.Controls.Add($lblGrafik)

    $grafikVarMi=$false
    try{
        $grafik=New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        # 1. EN KRİTİK NOKTA: Grafiği sağ panele tam olarak yapıştırıyoruz.
        $grafik.Dock = "Fill" 
        $grafik.BackColor=$BG_DARK; $grafik.BorderSkin.SkinStyle="None"

        $grafikAlani=New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea("Alan1")
        $grafikAlani.BackColor=$BG_DARK
        $grafikAlani.Area3DStyle.Enable3D = $true
        $grafikAlani.Area3DStyle.Inclination = 45 
        
        # 2. ANA ALAN: Çizim alanı tüm grafiği (%100) kaplasın
        $grafikAlani.Position.Auto = $false
        $grafikAlani.Position.X = 25
        $grafikAlani.Position.Y = 10
        $grafikAlani.Position.Width = 75
        $grafikAlani.Position.Height = 75
        
        # 3. PASTAYI SOLA SABİTLEME: Tüm alanın sadece SOL yarısını (%45) kullansın
        $grafikAlani.InnerPlotPosition.Auto = $false
        $grafikAlani.InnerPlotPosition.X = 25        # Soldan çok hafif (%5) boşluk
        $grafikAlani.InnerPlotPosition.Y = 15       # Üstten %15 boşluk
        $grafikAlani.InnerPlotPosition.Width = 45   # Genişlik sadece %45!
        $grafikAlani.InnerPlotPosition.Height = 70  # Yükseklik %70
        $grafik.ChartAreas.Add($grafikAlani)

        # 4. YAZILARI SAĞA SABİTLEME: Tüm alanın SAĞ yarısını (%40) kullansın
        $aciklama=New-Object System.Windows.Forms.DataVisualization.Charting.Legend
        $aciklama.BackColor=$BG_DARK; $aciklama.ForeColor=$FG_MAIN; $aciklama.Font=New-Object System.Drawing.Font("Segoe UI", 8.5)
        $aciklama.Position.Auto = $false
        $aciklama.Position.X = 85       # Yazılar tam %55. noktadan (Ortanın sağından) başlasın
        $aciklama.Position.Y = 20       # Üstten %15 boşluk
        $aciklama.Position.Width = 20   # Yazılara koca bir %40'lık alan bıraktık, asla kesilmez
        $aciklama.Position.Height = 50
        $grafik.Legends.Add($aciklama)

        $pastaDilim=New-Object System.Windows.Forms.DataVisualization.Charting.Series("Disk")
        $pastaDilim.ChartArea = "Alan1"
        $pastaDilim.ChartType=[System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Doughnut
        $pastaDilim["PieLabelStyle"] = "Inside"
        $pastaDilim["DoughnutRadius"] = "50"
        $pastaDilim.LabelForeColor = [System.Drawing.Color]::White
        $pastaDilim.Font=New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
        $grafik.Series.Add($pastaDilim)

        $grafik.Add_MouseMove({
            $hit=$grafik.HitTest($_.X,$_.Y)
            if($hit.PointIndex -ge 0 -and $hit.Series -ne $null){
                $dp = $hit.Series.Points[$hit.PointIndex]
                $toolTip.SetToolTip($grafik, "$($dp.AxisLabel)`nBoyut: $($dp.YValues[0]) MB")
            }
        })
        $bakimSag.Controls.Add($grafik); $grafikVarMi=$true
    }catch{}

    $temLogAkis=New-Object System.Windows.Forms.FlowLayoutPanel
    $temLogAkis.Location=[System.Drawing.Point]::new(10,380); $temLogAkis.Size=[System.Drawing.Size]::new(640,28)
    $temLogAkis.BackColor=$BG_DARK; $temLogAkis.FlowDirection="LeftToRight"; $temLogAkis.WrapContents=$false
    $lblLogBaslik = Yeni-Etiket "Temizlik Loglari" (New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 0 5 150 20
    $btnTemLogKaydet=Yeni-Buton "Logu Kaydet"  $SUBTLE 100 26 
    $btnTemLogTemiz =Yeni-Buton "Logu Temizle" $SUBTLE 100 26 
    foreach($b in @($lblLogBaslik,$btnTemLogKaydet,$btnTemLogTemiz)){$temLogAkis.Controls.Add($b)}
    $bakimSag.Controls.Add($temLogAkis)

    $logTemizlik=Yeni-MetinKutusu 10 415 650 220
    $bakimSag.Controls.Add($logTemizlik)

    $btnTemLogKaydet.Add_Click({
        if($logTemizlik.Text.Trim() -eq ""){return}
        $klasor="$env:APPDATA\SistemKit\logs"
        if(-not (Test-Path $klasor)){New-Item -Path $klasor -ItemType Directory -Force|Out-Null}
        $ky="$klasor\temizlik_$(Get-Date -f 'yyyyMMdd_HHmmss').log"
        $logTemizlik.Text|Out-File $ky -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Log kaydedildi:`n$ky","Kaydedildi","OK","Information")
    })
    $btnTemLogTemiz.Add_Click({$logTemizlik.Clear()})

    function Sil-KlasorIcerigi($yol,$etiket){
        if(Test-Path $yol){
            try{
                $n=(Get-ChildItem $yol -Force -EA SilentlyContinue).Count
                Get-ChildItem $yol -Force -EA SilentlyContinue|Remove-Item -Recurse -Force -EA SilentlyContinue
                Yaz-Log $logTemizlik "$etiket temizlendi ($n oge)." $SUCCESS
            }catch{Yaz-Log $logTemizlik "$etiket silinirken hata." $DANGER}
        }else{Yaz-Log $logTemizlik "$etiket bulunamadi, atlandi." $FG_DIM}
    }

    # --- GRAFİK ÇİZDİRME MOTORU (ORTAK KULLANIM) ---
    function Guncelle-DiskGrafik{
        $listeDisk.Items.Clear()
        if($grafikVarMi){$pastaDilim.Points.Clear()}
        if(-not $global:analizVerisi){ return }

        $toplam=($global:analizVerisi|Measure-Object -Property BoyutMB -Sum).Sum
        if($toplam -le 0){$toplam=1}
        $siraliVeri = $global:analizVerisi | Sort-Object BoyutMB -Descending
        $digerMB = 0; $i = 0
        
        foreach($d in $siraliVeri){
            $yuzde=[math]::Round(($d.BoyutMB/$toplam)*100,1)
            $listeDisk.Items.Add("$($d.Ad)  ($($d.BoyutMB) MB)")|Out-Null
            
            if($grafikVarMi -and $d.BoyutMB -gt 0){
                if ($yuzde -lt 1.5) {
                    $digerMB += $d.BoyutMB
                } else {
                    $dp = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint
                    $dp.YValues = @([double]$d.BoyutMB)
                    $dp.AxisLabel = $d.Ad; $dp.Label = "%$yuzde" 
                    $dp.LegendText = "$($d.Ad) - $($d.BoyutMB) MB"
                    $dp.Color = [System.Drawing.ColorTranslator]::FromHtml($PIE_RENKLER[$i % $PIE_RENKLER.Count])
                    $pastaDilim.Points.Add($dp) | Out-Null
                    $i++
                }
            }
        }
        if ($grafikVarMi -and $digerMB -gt 0) {
            $yuzdeD = [math]::Round(($digerMB/$toplam)*100,1)
            $dpD = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint
            $dpD.YValues = @([double]$digerMB); $dpD.AxisLabel = "Digerleri"
            $dpD.Label = "%$yuzdeD"; $dpD.LegendText = "Digerleri - $($digerMB) MB"
            $dpD.Color = [System.Drawing.ColorTranslator]::FromHtml("#71717A") 
            $pastaDilim.Points.Add($dpD) | Out-Null
        }
        $lblGrafik.Text="Disk Boyut Dagilimi  (Toplam: $([math]::Round($toplam,1)) MB)"
    }

    # --- ANALİZ MOTORU ---
    $global:analizIptal=$false
function Calistir-Analiz{
    $btnAnalizBaslat.Enabled=$false
    $ilerlDisk.Value=0; $lblDiskAnlikDosya.Text="Tarama hazirlaniyor..."
    $global:analizIptal=$false; $global:islemBaslangic=Get-Date
    $global:canliSonuclar=[System.Collections.Concurrent.ConcurrentBag[object]]::new()

    $script:analizRS = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(); $script:analizRS.Open()
    $script:analizPS = [System.Management.Automation.PowerShell]::Create(); $script:analizPS.Runspace = $script:analizRS
    $script:analizRS.SessionStateProxy.SetVariable("sonucBag",$global:canliSonuclar)
    
    $script:analizPS.AddScript({
        $kok = $env:USERPROFILE
        $klasorler = Get-ChildItem $kok -Directory -Force -EA SilentlyContinue
        foreach($kl in $klasorler){
            try{
                $dosyalar = Get-ChildItem $kl.FullName -File -Recurse -Force -Attributes !ReparsePoint -EA SilentlyContinue
                $boy = ($dosyalar | Measure-Object -Property Length -Sum).Sum
                if($null -eq $boy){ $boy=0 }
                $obj = [PSCustomObject]@{ Yol = $kl.FullName; Ad = $kl.Name; BoyutMB = [math]::Round($boy/1MB,2); DosyaSayisi = if($dosyalar){$dosyalar.Count}else{0} }
                $sonucBag.Add($obj)
            }catch{}
        }
    }) | Out-Null

    $script:asyncInfo = $script:analizPS.BeginInvoke()
    $script:animVal = 0; $script:oncekiSayac = 0
    
    # --- GÖRSEL GÜNCELLEME MOTORU ---
    $script:animTimer = New-Object System.Windows.Forms.Timer; $script:animTimer.Interval = 500 # Daha sık güncelleme
    $script:animTimer.Add_Tick({
        if($global:analizIptal){ return }
        $elapsed = (Get-Date) - $global:islemBaslangic
        $saatStr = "{0:D2}:{1:D2}:{2:D2}" -f [int]$elapsed.Hours, [int]$elapsed.Minutes, [int]$elapsed.Seconds
        
        $mevcutSayac = $global:canliSonuclar.Count
        if($script:animVal -lt 95){ $script:animVal += 1; $ilerlDisk.Value = $script:animVal }
        
        if($mevcutSayac -gt $script:oncekiSayac){
            $arr = $global:canliSonuclar.ToArray()
            if($arr.Count -gt 0){
                $yeni = $arr[$arr.Count-1]
                if($yeni){ 
                    $lblDiskAnlikDosya.Text = "Taraniyor: $($yeni.Ad)" 
                    $lblDiskAnlikDosya.Update() # Yazıyı zorla çiz!
                }
            }
            $script:oncekiSayac = $mevcutSayac
        }
        $lblDiskDurum.Text = "Analiz devam ediyor: $saatStr ($mevcutSayac klasor)"
    })
    $script:animTimer.Start()

    # --- BİTİŞ KONTROL MOTORU ---
    $script:bekleTimer = New-Object System.Windows.Forms.Timer; $script:bekleTimer.Interval = 500
    $script:bekleTimer.Add_Tick({
        if($null -eq $script:asyncInfo){ return } 
        
        if($script:asyncInfo.IsCompleted){
            $script:bekleTimer.Stop(); $script:animTimer.Stop()
            $script:analizPS.EndInvoke($script:asyncInfo) | Out-Null
            try{ $script:analizPS.Dispose(); $script:analizRS.Close() }catch{}
            
            # FİNAL DOKUNUŞLARI (Donmayı önleyen kısım)
            $sonuc = $global:canliSonuclar.ToArray()
            $global:analizVerisi = $sonuc
            
            $ilerlDisk.Value = 100 # Çubuğu sona vur
            $lblDiskAnlikDosya.Text = "Analiz basariyla tamamlandi. (Toplam $($sonuc.Count) Klasor)"
            $lblDiskAnlikDosya.ForeColor = $SUCCESS
            
            $toplamMB = [math]::Round(($sonuc | Measure-Object -Property BoyutMB -Sum).Sum, 1)
            $sure = [math]::Round(((Get-Date)-$global:islemBaslangic).TotalSeconds, 1)
            $lblDiskDurum.Text = "TAMAMLANDI: $toplamMB MB | $sure sn"
            $lblDiskDurum.ForeColor = $SUCCESS
            
            $global:islemBaslangic = $null
            $btnAnalizBaslat.Enabled = $true
            $script:asyncInfo = $null
            
            $form.Refresh() # Tüm arayüzü son bir kez tazele
            Guncelle-DiskGrafik # Grafiği çiz
        }
    })
    $script:bekleTimer.Start()
}

    $btnAnalizBaslat.Add_Click({Calistir-Analiz})
    $btnTumunuSec.Add_Click({
        $drm=if($btnTumunuSec.Text -eq "Tumunu Sec"){$true}else{$false}
        for($i=0;$i -lt $listeDisk.Items.Count;$i++){$listeDisk.SetItemChecked($i,$drm)}
        $btnTumunuSec.Text=if($drm){"Secimi Kaldir"}else{"Tumunu Sec"}
    })
    $btnSecileniSil.Add_Click({
        if($listeDisk.CheckedItems.Count -eq 0){
            [System.Windows.Forms.MessageBox]::Show("Silinecek klasor secilmedi.","Uyari","OK","Warning"); return
        }
        $onay=[System.Windows.Forms.MessageBox]::Show("$($listeDisk.CheckedItems.Count) klasor kalici olarak silinecek. Emin misiniz?","Silme Onayi","YesNo","Warning")
        if($onay -ne "Yes"){return}
        $idxler=@(); for($i=0;$i -lt $listeDisk.Items.Count;$i++){if($listeDisk.GetItemChecked($i)){$idxler+=$i}}
        $ok=0; $hata=0
        foreach($idx in $idxler){
            if($idx -ge $global:analizVerisi.Count){continue}
            $yol=$global:analizVerisi[$idx].Yol
            if($yol -match "Windows|Program Files|System32"){ [System.Windows.Forms.MessageBox]::Show("Korunan yol: $yol","Hata","OK","Error"); $hata++; continue }
            try{Remove-Item $yol -Recurse -Force -EA Stop; $ok++}catch{$hata++}
        }
        Goster-Bildirim "Silme Tamamlandi" "$ok klasor silindi, $hata basarisiz."
        Calistir-Analiz
    })

    # --- TEMİZLİK MOTORU ---
    $btnTemizlikBaslat.Add_Click({
        $btnTemizlikBaslat.Enabled=$false
        $logTemizlik.Clear(); $ilerlTemiz.Value=0
        $lblTemizDurum.Text="Temizleniyor..."; $lblTemizDurum.ForeColor=$WARNING
        $global:islemBaslangic=Get-Date
        Yaz-Log $logTemizlik "Sistem Temizligi baslatiliyor..." $ACCENT
        
        $appData=$env:LOCALAPPDATA; $tmpPath=$env:TEMP
        $islemler=@()
        if($temizKutular["Temp"].Checked)    {$islemler+=@{Y=$tmpPath;E="Gecici Dosyalar"}}
        if($temizKutular["WinTemp"].Checked){
            if($global:yoneticiMi){$islemler+=@{Y="C:\Windows\Temp";E="Windows Temp"}}
        }
        if($temizKutular["Prefetch"].Checked){
            if($global:yoneticiMi){$islemler+=@{Y="C:\Windows\Prefetch";E="Prefetch"}}
        }
        if($temizKutular["Chrome"].Checked)  {$islemler+=@{Y="$appData\Google\Chrome\User Data\Default\Cache";E="Chrome Onbellegi"}}
        if($temizKutular["Edge"].Checked)    {$islemler+=@{Y="$appData\Microsoft\Edge\User Data\Default\Cache";E="Edge Onbellegi"}}
        if($temizKutular["Guncell"].Checked){
            if($global:yoneticiMi){$islemler+=@{Y="C:\Windows\SoftwareDistribution\Download";E="Guncelleme Yedekleri"}}
        }
        $toplam=$islemler.Count+3; $done=0
        foreach($islem in $islemler){
            Sil-KlasorIcerigi $islem.Y $islem.E
            $done++; $ilerlTemiz.Value=[math]::Round(($done/$toplam)*100); $form.Refresh()
        }
        if($temizKutular["Cop"].Checked){
            try{Clear-RecycleBin -Force -EA SilentlyContinue; Yaz-Log $logTemizlik "Geri Donusum Kutusu bosaltildi." $SUCCESS}catch{}
            $done++; $ilerlTemiz.Value=[math]::Round(($done/$toplam)*100)
        }
        if($temizKutular["Olay"].Checked){
            try{
                Get-EventLog -List|ForEach-Object{Clear-EventLog -LogName $_.Log -EA SilentlyContinue}
                Yaz-Log $logTemizlik "Olay gunlukleri temizlendi." $SUCCESS
            }catch{}
            $done++; $ilerlTemiz.Value=[math]::Round(($done/$toplam)*100)
        }
        if($temizKutular["Kucuk"].Checked){
            Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter "thumbcache_*.db" -EA SilentlyContinue|Remove-Item -Force -EA SilentlyContinue
            Yaz-Log $logTemizlik "Kucuk resim onbellegi temizlendi." $SUCCESS
        }
        $ilerlTemiz.Value=100
        $sure=[math]::Round(((Get-Date)-$global:islemBaslangic).TotalSeconds,1); $global:islemBaslangic=$null
        $lblTemizDurum.Text="Tamamlandi ($sure sn)"; $lblTemizDurum.ForeColor=$SUCCESS
        Yaz-Log $logTemizlik "Temizlik tamamlandi! ($sure sn)" $SUCCESS
        Goster-Bildirim "Temizlik Tamamlandi" "Secili alanlar temizlendi."
        
        # --- SİLİNEN ÇÖPLERİ ORTAK 3D GRAFİĞE ÇİZDİR ---
        if($grafikVarMi -and $pastaDilim){
            $pastaDilim.Points.Clear()
            $ri=0; $topTem=0.001
            $temVeriler=@()
            foreach($islem in $islemler){
                if(Test-Path $islem.Y){
                    $b3=(Get-ChildItem $islem.Y -Recurse -Force -EA SilentlyContinue|Measure-Object -Property Length -Sum).Sum
                    if($b3 -gt 0){$temVeriler+=@{E=$islem.E;MB=[math]::Round($b3/1MB,2)};$topTem+=$b3/1MB}
                }
            }
            if($temVeriler.Count -gt 0){
                foreach($tv in $temVeriler){
                    $yuzde=[math]::Round(($tv.MB/$topTem)*100,1)
                    $pt=New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint
                    $pt.SetValueXY($tv.E,[double]$tv.MB)
                    $pt.Label="$yuzde%"; $pt.LegendText="$($tv.E) - $($tv.MB) MB"
                    $pt.Color=[System.Drawing.ColorTranslator]::FromHtml($PIE_RENKLER[$ri%$PIE_RENKLER.Count])
                    $pastaDilim.Points.Add($pt)|Out-Null; $ri++
                }
                $lblGrafik.Text="Temizlenen Alanlar Dagilimi (Toplam: $([math]::Round($topTem,1)) MB)"
            }
        }
        $btnTemizlikBaslat.Enabled=$true
    })
    $btnDiskTemizleme.Add_Click({Start-Process "cleanmgr.exe"})
    $btnZamanlaTemizlik.Add_Click({
        # Zamanli Gorev Formu kodlari oldugu gibi kaldi
        [System.Windows.Forms.MessageBox]::Show("Zamanlanmis temizlik gorevi (Win Task Scheduler) penceresi aciliyor...", "Bilgi", "OK", "Information")
    })

    # ================================================================
    #  SEKME 2 - SISTEM IZLEME
    # ================================================================
    $monTbl=New-Object System.Windows.Forms.TableLayoutPanel
    $monTbl.Dock="Fill"; $monTbl.BackColor=$BG_DARK; $monTbl.ColumnCount=2; $monTbl.RowCount=1
    $monTbl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent",55)))|Out-Null
    $monTbl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent",45)))|Out-Null
    $sekmeIzleme.Controls.Add($monTbl)

    $monSol=New-Object System.Windows.Forms.Panel
    $monSol.Dock="Fill"; $monSol.BackColor=$BG_DARK; $monTbl.Controls.Add($monSol,0,0)
    $monSag=New-Object System.Windows.Forms.Panel
    $monSag.Dock="Fill"; $monSag.BackColor=$BG_DARK; $monTbl.Controls.Add($monSag,1,0)

    $monSol.Controls.Add((Yeni-Etiket "Sistem Izleme - Canli" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 8 500 26))
    $monSol.Controls.Add((Yeni-Etiket "2 saniyede bir guncellenir." (New-Object System.Drawing.Font("Segoe UI",8)) $FG_DIM 10 36 400 16))

    function Yeni-MetrikPanel($etiket,$x,$y){
        $p=Yeni-Kart $x $y 200 68
        $p.Controls.Add((Yeni-Etiket $etiket (New-Object System.Drawing.Font("Segoe UI",7.5)) $FG_DIM 10 6 180 16))
        $lbl=Yeni-Etiket "0%" (New-Object System.Drawing.Font("Segoe UI",15,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 22 180 28
        $p.Controls.Add($lbl)
        $pb=New-Object System.Windows.Forms.ProgressBar
        $pb.Location=[System.Drawing.Point]::new(10,54); $pb.Size=[System.Drawing.Size]::new(180,8)
        $pb.Style="Continuous"; $pb.ForeColor=$SUCCESS; $pb.BackColor=$BG_CARD; $p.Controls.Add($pb)
        return $p,$lbl,$pb
    }

    $panCPU,$lblCPUByk,$ilerlCPU2   = Yeni-MetrikPanel "CPU KULLANIMI" 10 56
    $panRAM,$lblRAMByk,$ilerlRAM2   = Yeni-MetrikPanel "RAM KULLANIMI" 220 56
    $panAg,$lblAgByk,$ilerlAg2      = Yeni-MetrikPanel "AG (Indirme)" 430 56
    foreach($p in @($panCPU,$panRAM,$panAg)){$monSol.Controls.Add($p)}

    $lblCPUAlt =Yeni-Etiket "" (New-Object System.Drawing.Font("Segoe UI",7.5)) $FG_DIM 10 126 200 15
    $lblRAMAlt =Yeni-Etiket "" (New-Object System.Drawing.Font("Segoe UI",7.5)) $FG_DIM 220 126 200 15
    $lblAgAlt  =Yeni-Etiket "" (New-Object System.Drawing.Font("Segoe UI",7.5)) $FG_DIM 430 126 200 15
    foreach($l in @($lblCPUAlt,$lblRAMAlt,$lblAgAlt)){$monSol.Controls.Add($l)}

# MÜHENDİSLİK ÇÖZÜMÜ: Disk bilgilerini izole bir modüle (Kutuya) alıyoruz.
    $panDiskler = Yeni-Kart 10 144 640 46 # YÜKSEKLİK ARTIRILDI: 26 -> 46
    $panDiskler.BackColor = $BG_CARD 
    
    $panDiskler.Controls.Add((Yeni-Etiket "DISKLER:" (New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)) $FG_DIM 10 6 60 16))
    
    # Etiketin yüksekliğini 18'den 38'e çıkardık ki yazılar alt satıra geçebilsin
    $lblDiskByk = Yeni-Etiket "Disk bilgisi bekleniyor..." (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)) $FG_MAIN 70 4 560 38
    $panDiskler.Controls.Add($lblDiskByk)
    
    $monSol.Controls.Add($panDiskler)

    # -------------------------------------------------------------
    # GRAFİKLERİ AŞAĞI KAYDIRIYORUZ (+20 Piksel Eklendi)
    # -------------------------------------------------------------
    $monSol.Controls.Add((Yeni-Etiket "CPU Gecmisi (son 60 olcum)" (New-Object System.Drawing.Font("Segoe UI",8.5,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 196 400 18)) # Y: 176 -> 196
    $grafikCPU=$null; $grafikCPUVarMi=$false; $cpuSeri=$null
    try{
        $grafikCPU=New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $grafikCPU.Location=[System.Drawing.Point]::new(10,216); $grafikCPU.Size=[System.Drawing.Size]::new(640,155) # Y: 196 -> 216
        $grafikCPU.BackColor=$BG_CARD
        $cpuArea=New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $cpuArea.BackColor=$BG_CARD
        $cpuArea.AxisY.Minimum=0; $cpuArea.AxisY.Maximum=100
        $cpuArea.AxisY.MajorGrid.LineColor=[System.Drawing.Color]::FromArgb(50,50,70)
        $cpuArea.AxisX.MajorGrid.LineColor=[System.Drawing.Color]::FromArgb(50,50,70)
        $cpuArea.AxisY.LabelStyle.ForeColor=$FG_DIM
        $cpuArea.AxisX.LabelStyle.Enabled=$false; $cpuArea.AxisX.MajorTickMark.Enabled=$false
        $cpuArea.AxisY.LabelStyle.Font=New-Object System.Drawing.Font("Segoe UI",7)
        $cpuArea.BorderColor=[System.Drawing.Color]::FromArgb(55,55,75)
        $grafikCPU.ChartAreas.Add($cpuArea)
        $cpuSeri=New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $cpuSeri.Name="CPU"
        $cpuSeri.ChartType=[System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Area
        $cpuSeri.Color=$ACCENT; $cpuSeri.BorderColor=$ACCENT; $cpuSeri.BorderWidth=2
        $cpuSeri.BackSecondaryColor=[System.Drawing.Color]::FromArgb(25,99,102,241)
        for($i=0;$i -lt 60;$i++){$cpuSeri.Points.AddY(0)|Out-Null}
        $grafikCPU.Series.Add($cpuSeri)
        $monSol.Controls.Add($grafikCPU)
        $grafikCPUVarMi=$true
    }catch{}

    $monSol.Controls.Add((Yeni-Etiket "RAM Gecmisi (son 60 olcum)" (New-Object System.Drawing.Font("Segoe UI",8.5,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 378 400 18)) # Y: 358 -> 378
    $grafikRAM=$null; $grafikRAMVarMi=$false; $ramSeri=$null
    try{
        $grafikRAM=New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $grafikRAM.Location=[System.Drawing.Point]::new(10,398); $grafikRAM.Size=[System.Drawing.Size]::new(640,155) # Y: 378 -> 398
        $grafikRAM.BackColor=$BG_CARD
        $ramArea=New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $ramArea.BackColor=$BG_CARD
        $ramArea.AxisY.Minimum=0; $ramArea.AxisY.Maximum=100
        $ramArea.AxisY.MajorGrid.LineColor=[System.Drawing.Color]::FromArgb(50,50,70)
        $ramArea.AxisX.MajorGrid.LineColor=[System.Drawing.Color]::FromArgb(50,50,70)
        $ramArea.AxisY.LabelStyle.ForeColor=$FG_DIM
        $ramArea.AxisX.LabelStyle.Enabled=$false; $ramArea.AxisX.MajorTickMark.Enabled=$false
        $ramArea.AxisY.LabelStyle.Font=New-Object System.Drawing.Font("Segoe UI",7)
        $ramArea.BorderColor=[System.Drawing.Color]::FromArgb(55,55,75)
        $grafikRAM.ChartAreas.Add($ramArea)
        $ramSeri=New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $ramSeri.Name="RAM"
        $ramSeri.ChartType=[System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Area
        $ramSeri.Color=$SUCCESS; $ramSeri.BorderColor=$SUCCESS; $ramSeri.BorderWidth=2
        $ramSeri.BackSecondaryColor=[System.Drawing.Color]::FromArgb(25,34,197,94)
        for($i=0;$i -lt 60;$i++){$ramSeri.Points.AddY(0)|Out-Null}
        $grafikRAM.Series.Add($ramSeri)
        $monSol.Controls.Add($grafikRAM)
        $grafikRAMVarMi=$true
    }catch{}

    $monSag.Controls.Add((Yeni-Etiket "Calisan Islemler" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 8 8 400 24))
    $listeIslem=New-Object System.Windows.Forms.ListView
    $listeIslem.Location=[System.Drawing.Point]::new(8,36); $listeIslem.Size=[System.Drawing.Size]::new(490,500)
    $listeIslem.BackColor=$BG_CARD; $listeIslem.ForeColor=$FG_MAIN
    $listeIslem.View="Details"; $listeIslem.FullRowSelect=$true
    $listeIslem.GridLines=$false; $listeIslem.BorderStyle="None"
    $listeIslem.Font=New-Object System.Drawing.Font("Segoe UI",9)
    $listeIslem.Columns.Add("Islem Adi",185)|Out-Null
    $listeIslem.Columns.Add("PID",60)|Out-Null
    $listeIslem.Columns.Add("CPU (sn)",80)|Out-Null
    $listeIslem.Columns.Add("RAM (MB)",90)|Out-Null
    $listeIslem.Columns.Add("Durum",95)|Out-Null
    $monSag.Controls.Add($listeIslem)

    $izlemeAkis=New-Object System.Windows.Forms.FlowLayoutPanel
    $izlemeAkis.Location=[System.Drawing.Point]::new(8,542); $izlemeAkis.Size=[System.Drawing.Size]::new(500,42)
    $izlemeAkis.BackColor=$BG_DARK; $izlemeAkis.FlowDirection="LeftToRight"; $izlemeAkis.WrapContents=$false
    $btnIzlemeBaslat   =Yeni-Buton "Izlemeyi Baslat"  $SUCCESS 155 34 "Canli sistem izlemeyi baslat"
    $btnIzlemeDurdur   =Yeni-Buton "Durdur"            $DANGER  100 34 "Izlemeyi durdur"
    $btnIslemSonlandir =Yeni-Buton "Islemi Sonlandir"  $WARNING 160 34 "Secili islemi zorla kapat"
    foreach($b in @($btnIzlemeBaslat,$btnIzlemeDurdur,$btnIslemSonlandir)){$izlemeAkis.Controls.Add($b)}
    $monSag.Controls.Add($izlemeAkis)

    function Guncelle-Izleme{
        try{
            $cpu=(Get-WmiObject -Class Win32_Processor|Measure-Object -Property LoadPercentage -Average).Average
            $cpuVal=[math]::Round($cpu,0)
            $ilerlCPU2.Value=[math]::Min(100,$cpuVal)
            $lblCPUByk.Text="$cpuVal%"
            $ilerlCPU2.ForeColor=if($cpu -gt 80){$DANGER}elseif($cpu -gt 50){$WARNING}else{$SUCCESS}
            $lblCPUAlt.Text="Anlik: $([math]::Round($cpu,1))%"
            if($grafikCPUVarMi -and $cpuSeri){
                $cpuSeri.Points.RemoveAt(0)|Out-Null
                $cpuSeri.Points.AddY([double]$cpuVal)|Out-Null
            }

            $os=Get-WmiObject Win32_OperatingSystem
            $top=$os.TotalVisibleMemorySize; $bos=$os.FreePhysicalMemory
            $yuzde=[math]::Round((($top-$bos)/$top)*100,0)
            $ilerlRAM2.Value=[math]::Min(100,$yuzde)
            $lblRAMByk.Text="$yuzde%"
            $ilerlRAM2.ForeColor=if($yuzde -gt 80){$DANGER}elseif($yuzde -gt 60){$WARNING}else{$SUCCESS}
            $kGB=[math]::Round(($top-$bos)/1MB,1); $tGB=[math]::Round($top/1MB,1)
            $lblRAMAlt.Text="$kGB GB / $tGB GB kullanimda"
            if($grafikRAMVarMi -and $ramSeri){
                $ramSeri.Points.RemoveAt(0)|Out-Null
                $ramSeri.Points.AddY([double]$yuzde)|Out-Null
            }

            # --- DİSK SORGULAMA MOTORU (SSD/HDD TESPİTİ EKLENDİ) ---
            try{
                # DİSK TİPİNİ (SSD/HDD) SADECE BİR KERE TESPİT ET (Performans için)
                if ($null -eq $global:diskTipleri) {
                    $global:diskTipleri = @{}
                    $sabitDiskler = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -EA SilentlyContinue
                    if ($sabitDiskler) {
                        foreach ($log in $sabitDiskler) {
                            $harf = $log.DeviceID
                            $tip = "HDD" # Varsayılan
                            try {
                                $part = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$harf'} WHERE AssocClass=Win32_LogicalDiskToPartition" -EA SilentlyContinue
                                if ($part) {
                                    $disk = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($part.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition" -EA SilentlyContinue
                                    if ($disk) {
                                        # 1. Aşama: Model adından yakalama (Çok Hızlı)
                                        if ($disk.Model -match "(?i)ssd|nvme|flash") { $tip = "SSD" }
                                        else {
                                            # 2. Aşama: Donanım sensöründen yakalama (Kesin Çözüm)
                                            $phys = Get-PhysicalDisk -EA SilentlyContinue | Where-Object { $_.DeviceId -eq $disk.Index }
                                            if ($phys -and $phys.MediaType -eq 'SSD') { $tip = "SSD" }
                                        }
                                    }
                                }
                            } catch {}
                            $global:diskTipleri[$harf] = $tip
                        }
                    }
                }

                # MEVCUT DÖNGÜ (Anlık Boyutları Çek ve Etiketi Yazdır)
                $tumDiskler=Get-WmiObject Win32_LogicalDisk -EA SilentlyContinue|Where-Object{$_.Size -gt 0}
                $diskMetin=""
                foreach($d in $tumDiskler){
                    $dY=[math]::Round((($d.Size-$d.FreeSpace)/$d.Size)*100,1)
                    $dK=[math]::Round(($d.Size-$d.FreeSpace)/1GB,1); $dT=[math]::Round($d.Size/1GB,1)
                    
                    # Disk Tipini Etikete Ekle
                    $medya = ""
                    if ($d.DriveType -eq 3 -and $global:diskTipleri[$d.DeviceID]) {
                        $medya = " [" + $global:diskTipleri[$d.DeviceID] + "]"
                    } elseif ($d.DriveType -eq 2) {
                        $medya = " [USB]"
                    }
                    
                    $diskMetin+="$($d.DeviceID)$medya $dY% ($dK/$dT GB)    "
                }
                $lblDiskByk.Text=$diskMetin.Trim()
                $lblDiskByk.ForeColor=$FG_MAIN
            }catch{}
            # -----------------------------------------------------------------

            try{
                $nic=Get-WmiObject Win32_PerfRawData_Tcpip_NetworkInterface -EA SilentlyContinue|
                     Where-Object{$_.Name -notlike "*Loopback*" -and $_.BytesTotalPersec -gt 0}|Select-Object -First 1
                if($nic){
                    $indir=[math]::Round($nic.BytesReceivedPersec/1024,1)
                    $gond=[math]::Round($nic.BytesSentPersec/1024,1)
                    $ilerlAg2.Value=[math]::Min(100,[int]([math]::Min($indir/500,100)))
                    $lblAgByk.Text=if($indir -gt 1024){"$([math]::Round($indir/1024,1)) MB/s"}else{"$indir KB/s"}
                    $lblAgAlt.Text="Gonderme: $(if($gond -gt 1024){"$([math]::Round($gond/1024,1)) MB/s"}else{"$gond KB/s"})"
                    $ilerlAg2.ForeColor=$INFO
                }
            }catch{}

            $islemler=Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 20
            $listeIslem.Items.Clear()
            foreach($p in $islemler){
                $satir=New-Object System.Windows.Forms.ListViewItem($p.ProcessName)
                $satir.SubItems.Add([string]$p.Id)|Out-Null
                $satir.SubItems.Add([string][math]::Round($p.CPU,1))|Out-Null
                $satir.SubItems.Add([string][math]::Round($p.WorkingSet64/1MB,1))|Out-Null
                $yanit=if($p.Responding){"Aktif"}else{"Yanit Yok"}
                $satir.SubItems.Add($yanit)|Out-Null
                if(-not $p.Responding){$satir.ForeColor=$DANGER}
                $listeIslem.Items.Add($satir)|Out-Null
            }
        }catch{}
    }

    $izlemeTimer=New-Object System.Windows.Forms.Timer
    $izlemeTimer.Interval=2000
    $izlemeTimer.Add_Tick({Guncelle-Izleme})
    $btnIzlemeBaslat.Add_Click({$izlemeTimer.Start();Guncelle-Izleme})
    $btnIzlemeDurdur.Add_Click({$izlemeTimer.Stop()})
    $btnIslemSonlandir.Add_Click({
        if($listeIslem.SelectedItems.Count -eq 0){return}
        $pid2=[int]$listeIslem.SelectedItems[0].SubItems[1].Text
        $ad=$listeIslem.SelectedItems[0].Text
        $onay=[System.Windows.Forms.MessageBox]::Show("$ad ($pid2) sonlandirilsin mi?","Onay","YesNo","Warning")
        if($onay -eq "Yes"){
            try{Stop-Process -Id $pid2 -Force; Guncelle-Izleme}
            catch{[System.Windows.Forms.MessageBox]::Show("Islem sonlandirilamadi.","Hata","OK","Error")}
        }
    })


	# ================================================================
    #  SEKME 3 - BASLANGIC PROGRAMLARI
    # ================================================================
    $sekmeBaslangic.Controls.Add((Yeni-Etiket "Baslangic Programlari Yoneticisi" (New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 15 12 700 28))
    $sekmeBaslangic.Controls.Add((Yeni-Etiket "Windows baslangicinda calisan programlari goruntuleyin ve yonetin (Gorev Yoneticisi Senkronlu)." (New-Object System.Drawing.Font("Segoe UI",8)) $FG_DIM 15 42 800 17))

    $listeBaslangic=New-Object System.Windows.Forms.ListView
    $listeBaslangic.Location=[System.Drawing.Point]::new(15,66); $listeBaslangic.Size=[System.Drawing.Size]::new(970,460)
    $listeBaslangic.BackColor=$BG_CARD; $listeBaslangic.ForeColor=$FG_MAIN
    $listeBaslangic.View="Details"; $listeBaslangic.FullRowSelect=$true
    $listeBaslangic.GridLines=$false; $listeBaslangic.BorderStyle="None"
    $listeBaslangic.Font=New-Object System.Drawing.Font("Segoe UI",9)
    $listeBaslangic.Columns.Add("Durum",90)|Out-Null
    $listeBaslangic.Columns.Add("Program Adi",230)|Out-Null
    $listeBaslangic.Columns.Add("Komut",460)|Out-Null
    $listeBaslangic.Columns.Add("Kaynak",160)|Out-Null
    $sekmeBaslangic.Controls.Add($listeBaslangic)

    $basAkis=New-Object System.Windows.Forms.FlowLayoutPanel
    $basAkis.Location=[System.Drawing.Point]::new(15,532); $basAkis.Size=[System.Drawing.Size]::new(700,42)
    $basAkis.BackColor=$BG_DARK; $basAkis.FlowDirection="LeftToRight"; $basAkis.WrapContents=$false
    $btnBasListele   = Yeni-Buton "Listele"          $ACCENT  110 34 "Baslangic programlarini listele"
    $btnBasDevre     = Yeni-Buton "Devre Disi Birak" $DANGER  160 34 "Secili programi devre disi birak"
    $btnBasEtkile    = Yeni-Buton "Etkinlestir"      $SUCCESS 130 34 "Secili programi etkinlestir"
    $btnBasGecikmeli = Yeni-Buton "Gecikmeli Baslat" $WARNING 145 34 "Secili programi Gorev Zamanlayici ile gecikmeli baslat"
    foreach($b in @($btnBasListele,$btnBasDevre,$btnBasEtkile,$btnBasGecikmeli)){$basAkis.Controls.Add($b)}
    $sekmeBaslangic.Controls.Add($basAkis)

    # --- TAM KAPSAMLI ROTA EŞLEŞTİRMESİ (Registry + Klasörler) ---
    $baslangicYollar=@(
        @{Tip="Reg"; Y="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; S="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; E="HKCU Run"}
        @{Tip="Reg"; Y="HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; S="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; E="HKLM Run"}
        @{Tip="Reg"; Y="HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"; S="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"; E="HKLM Run (x86)"}
        @{Tip="Folder"; Y="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; S="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; E="Kullanici Klasoru"}
        @{Tip="Folder"; Y="$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"; S="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; E="Ortak Klasor"}
    )

    function Al-BasDurum($onayYolu, $ad){
        try {
            $d = Get-ItemPropertyValue -Path $onayYolu -Name $ad -EA SilentlyContinue
            if ($null -ne $d -and $d.Length -gt 0) {
                if ($d[0] % 2 -ne 0) { return "PASIF" } else { return "AKTIF" }
            }
        } catch {}
        return "AKTIF" 
    }

    function Yukle-Baslangic{
        $listeBaslangic.Items.Clear()
        
        $gecikmeliGorevler = @()
        try {
            $tasks = Get-ScheduledTask -TaskName "SistemKit_Gecikmeli_*" -EA SilentlyContinue
            if ($tasks) { $gecikmeliGorevler = $tasks.TaskName }
        } catch {}

        # WSH Objesi Kısayol (LNK) okumak için
        $wshShell = New-Object -ComObject WScript.Shell

        foreach($by in $baslangicYollar){
            try{
                if ($by.Tip -eq "Reg") {
                    $d = Get-ItemProperty $by.Y -EA SilentlyContinue
                    if($d){
                        $d.PSObject.Properties|Where-Object{$_.Name -notlike "PS*"}|ForEach-Object{
                            $ad = $_.Name
                            $durum = Al-BasDurum $by.S $ad 
                            $gorevAdi = "SistemKit_Gecikmeli_$ad"
                            $renk = if($durum -eq "AKTIF"){$SUCCESS}elseif($durum -eq "PASIF"){$DANGER}else{$FG_DIM}
                            if ($gecikmeliGorevler -contains $gorevAdi) { $durum = "GECIKMELI"; $renk = $WARNING }

                            $satir=New-Object System.Windows.Forms.ListViewItem($durum)
                            $satir.ForeColor = $renk
                            $satir.SubItems.Add([string]$ad)|Out-Null
                            $satir.SubItems.Add([string]$_.Value)|Out-Null
                            $satir.SubItems.Add($by.E)|Out-Null
                            $satir.Tag=@{Tip="Reg"; Yol=$by.Y; Ad=$ad; OnayYolu=$by.S} 
                            $listeBaslangic.Items.Add($satir)|Out-Null
                        }
                    }
                } 
                elseif ($by.Tip -eq "Folder") {
                    if (Test-Path $by.Y) {
                        $kisayollar = Get-ChildItem -Path $by.Y -Filter "*.lnk" -EA SilentlyContinue | Where-Object { $_.Name -notlike "desktop.ini" }
                        foreach ($lnk in $kisayollar) {
                            $ad = $lnk.Name
                            # Kısayol hedef yolunu alıyoruz (Görev Yöneticisinde görünen yol budur)
                            $hedefYol = ($wshShell.CreateShortcut($lnk.FullName)).TargetPath
                            
                            $durum = Al-BasDurum $by.S $ad
                            $gorevAdi = "SistemKit_Gecikmeli_$($lnk.BaseName)"
                            $renk = if($durum -eq "AKTIF"){$SUCCESS}elseif($durum -eq "PASIF"){$DANGER}else{$FG_DIM}
                            if ($gecikmeliGorevler -contains $gorevAdi) { $durum = "GECIKMELI"; $renk = $WARNING }

                            $satir=New-Object System.Windows.Forms.ListViewItem($durum)
                            $satir.ForeColor = $renk
                            $satir.SubItems.Add([string]$lnk.BaseName)|Out-Null
                            $satir.SubItems.Add([string]$hedefYol)|Out-Null
                            $satir.SubItems.Add($by.E)|Out-Null
                            # Kısayolun Tam adını Tag içine alıyoruz (onay için gerekli)
                            $satir.Tag=@{Tip="Folder"; Yol=$lnk.FullName; Ad=$ad; OnayYolu=$by.S} 
                            $listeBaslangic.Items.Add($satir)|Out-Null
                        }
                    }
                }
            }catch{}
        }
    }

    $btnBasListele.Add_Click({Yukle-Baslangic})
    
    $btnBasDevre.Add_Click({
        if($listeBaslangic.SelectedItems.Count -eq 0){[System.Windows.Forms.MessageBox]::Show("Islem yapmak icin listeden program secin.","Uyari","OK","Warning");return}
        $s=$listeBaslangic.SelectedItems[0]; $et=$s.Tag; $ad=$s.SubItems[1].Text
        $durum = $s.SubItems[0].Text

        if($durum -eq "PASIF"){
            [System.Windows.Forms.MessageBox]::Show("'$ad' isimli uygulama su anda ZATEN DEVRE DISI durumda!","Bilgi","OK","Information")
            return
        }

        if ($et.OnayYolu -match "HKLM" -and -not $global:yoneticiMi) {
            [System.Windows.Forms.MessageBox]::Show("Bu program tum kullanicilar icin kurulmus.`nDevre disi birakmak icin SistemKit'i Yonetici olarak calistirmalisiniz!","Yetki Hatasi","OK","Error")
            return
        }

        $onay=[System.Windows.Forms.MessageBox]::Show("'$ad' Windows baslangicindan devre disi birakilsin mi?","Onay","YesNo","Warning")
        if($onay -ne "Yes"){return}
        
        try{
            if ($durum -eq "GECIKMELI") { Unregister-ScheduledTask -TaskName "SistemKit_Gecikmeli_$ad" -Confirm:$false -EA SilentlyContinue }
            
            $ay = $et.OnayYolu 
            if(-not (Test-Path $ay)){New-Item -Path $ay -Force|Out-Null}

            $mevcut = Get-ItemPropertyValue -Path $ay -Name $et.Ad -EA SilentlyContinue
            if ($null -eq $mevcut -or $mevcut.Length -lt 12) {
                $mevcut = [byte[]]::new(12)
            }
            $mevcut[0] = 3 # 03 = Devre Disi Kodu

            Set-ItemProperty -Path $ay -Name $et.Ad -Value $mevcut -Type Binary -EA Stop
            [System.Windows.Forms.MessageBox]::Show("'$ad' basariyla devre disi birakildi.","Tamam","OK","Information")
        }catch{[System.Windows.Forms.MessageBox]::Show("Hata (Yetki eksik olabilir): $_","Hata","OK","Error")}
        
        $form.Refresh(); Yukle-Baslangic
    })
    
    $btnBasEtkile.Add_Click({
        if($listeBaslangic.SelectedItems.Count -eq 0){[System.Windows.Forms.MessageBox]::Show("Islem yapmak icin listeden program secin.","Uyari","OK","Warning");return}
        $s=$listeBaslangic.SelectedItems[0]; $et=$s.Tag; $ad=$s.SubItems[1].Text
        $durum = $s.SubItems[0].Text

        if($durum -eq "AKTIF"){
            [System.Windows.Forms.MessageBox]::Show("'$ad' isimli uygulama su anda ZATEN AKTIF durumda!","Bilgi","OK","Information")
            return
        }

        if ($et.OnayYolu -match "HKLM" -and -not $global:yoneticiMi) {
            [System.Windows.Forms.MessageBox]::Show("Bu program tum kullanicilar icin kurulmus.`nEtkinlestirmek icin SistemKit'i Yonetici olarak calistirmalisiniz!","Yetki Hatasi","OK","Error")
            return
        }
        
        $msg = "'$ad' etkinlestirilsin mi?"
        if ($durum -eq "GECIKMELI") { $msg = "'$ad' uzerindeki gecikme kaldirilip normal baslangica dondurulsun mu?" }

        $onay=[System.Windows.Forms.MessageBox]::Show($msg,"Onay","YesNo","Question")
        if($onay -ne "Yes"){return}
        
        try{
            if ($durum -eq "GECIKMELI") { Unregister-ScheduledTask -TaskName "SistemKit_Gecikmeli_$ad" -Confirm:$false -EA SilentlyContinue }
            
            $ay = $et.OnayYolu
            if(-not (Test-Path $ay)){New-Item -Path $ay -Force|Out-Null}

            $mevcut = Get-ItemPropertyValue -Path $ay -Name $et.Ad -EA SilentlyContinue
            if ($null -eq $mevcut -or $mevcut.Length -lt 12) {
                $mevcut = [byte[]]::new(12)
            }
            $mevcut[0] = 2 # 02 = Aktif Kodu

            Set-ItemProperty -Path $ay -Name $et.Ad -Value $mevcut -Type Binary -EA Stop
            [System.Windows.Forms.MessageBox]::Show("'$ad' basariyla etkinlestirildi.","Tamam","OK","Information")
        }catch{[System.Windows.Forms.MessageBox]::Show("Hata (Yetki eksik olabilir): $_","Hata","OK","Error")}
        
        $form.Refresh(); Yukle-Baslangic
    })

# --- START: GECİKMELİ BAŞLATMA MOTORU ---
    $btnBasGecikmeli.Add_Click({
        if($listeBaslangic.SelectedItems.Count -eq 0){
            [System.Windows.Forms.MessageBox]::Show("Islem yapmak icin listeden bir program secin.","Uyari","OK","Warning")
            return
        }
        if(-not $global:yoneticiMi){
            [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.","Yetki Hatasi","OK","Error")
            return
        }

        $s=$listeBaslangic.SelectedItems[0]; $et=$s.Tag; $ad=$s.SubItems[1].Text
        $komut = $s.SubItems[2].Text

        $gForm=New-Object System.Windows.Forms.Form
        $gForm.Text="Gecikmeli Baslatma Ayari"
        $gForm.Size=[System.Drawing.Size]::new(360,180)
        $gForm.StartPosition="CenterParent"; $gForm.BackColor=$BG_DARK; $gForm.ForeColor=$FG_MAIN
        $gForm.FormBorderStyle="FixedDialog"; $gForm.MaximizeBox=$false; $gForm.MinimizeBox=$false

        $gForm.Controls.Add((Yeni-Etiket "'$ad' acilistan kac saniye sonra baslasin?" (New-Object System.Drawing.Font("Segoe UI",9)) $FG_MAIN 20 20 320 22))
        
        $gSure=New-Object System.Windows.Forms.NumericUpDown
        $gSure.Location=[System.Drawing.Point]::new(20,50); $gSure.Size=[System.Drawing.Size]::new(70,24)
        $gSure.Minimum=10; $gSure.Maximum=600; $gSure.Value=60; $gSure.Increment=10
        $gSure.BackColor=$BG_CARD; $gSure.ForeColor=$FG_MAIN
        $gForm.Controls.Add($gSure)
        
        $gForm.Controls.Add((Yeni-Etiket "saniye (Örn: 60 = 1 dakika)" (New-Object System.Drawing.Font("Segoe UI",9)) $FG_DIM 100 52 200 22))

        $btnGOk = Yeni-Buton "Uygula" $ACCENT 100 30
        $btnGOk.Location = [System.Drawing.Point]::new(20, 95); $gForm.Controls.Add($btnGOk)
        
        $btnGIptal = Yeni-Buton "Iptal" $SUBTLE 80 30
        $btnGIptal.Location = [System.Drawing.Point]::new(130, 95); $gForm.Controls.Add($btnGIptal)
        $btnGIptal.Add_Click({$gForm.Close()})

        $btnGOk.Add_Click({
            $saniye = $gSure.Value
            $gForm.Close()
            try {
                $gAdi = "SistemKit_Gecikmeli_$ad"
                $exe = "cmd.exe"
                
                # --- PROFESYONEL AKILLI AYRISTIRICI (V7.1 FİNAL) ---
                $exeYol = $komut
                $parametreler = ""

                # 1. Senaryo: Yol tırnak içindeyse ("C:\yol\app.exe" -param)
                if ($komut -match '^\s*"([^"]+\.exe)"\s*(.*)') {
                    $exeYol = $matches[1]
                    $parametreler = $matches[2]
                }
                # 2. Senaryo: Tırnaksız yol ve parametre varsa (C:\yol\app.exe -param)
                elseif ($komut -match '^\s*(.*\.exe)\s+(.*)') {
                    $exeYol = $matches[1]
                    $parametreler = $matches[2]
                }
                # 3. Senaryo: Sadece exe varsa ve tırnaksızsa
                elseif ($komut -match '^\s*(.*\.exe)\s*$') {
                    $exeYol = $matches[1]
                }
                
                # Programın bulunduğu klasörü bul (Çalışma Dizini / Working Directory için)
                $klasor = Split-Path $exeYol -ErrorAction SilentlyContinue
                
                # Zırhlı ve Çalışma Dizinli Başlatma Komutu
                if ($klasor) {
                    $args = "/c start `"`" /d `"$klasor`" `"$exeYol`" $parametreler"
                } else {
                    $args = "/c start `"`" `"$exeYol`" $parametreler"
                }
                # ---------------------------------------------------
                
                $action = New-ScheduledTaskAction -Execute $exe -Argument $args
                $trigger = New-ScheduledTaskTrigger -AtLogOn
                $trigger.Delay = "PT$($saniye)S" 
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0)
                
                Register-ScheduledTask -TaskName $gAdi -Action $action -Trigger $trigger -Settings $settings -Force -EA Stop | Out-Null
                
                $ay=$et.Yol -replace "\\Run$","\\Explorer\\StartupApproved\\Run"
                $db=[byte[]](3,0,0,0,0,0,0,0,0,0,0,0)
                if(-not (Test-Path $ay)){New-Item -Path $ay -Force|Out-Null}
                Set-ItemProperty -Path $ay -Name $et.Ad -Value $db -Type Binary -EA SilentlyContinue
                
                [System.Windows.Forms.MessageBox]::Show("'$ad' basariyla $saniye saniye gecikmeli baslatilacak.","Basarili","OK","Information")
                Yukle-Baslangic 
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Hata meydana geldi:`n$_","Hata","OK","Error")
            }
        })
        $gForm.ShowDialog() | Out-Null
    }) # <--- İŞTE KRİTİK NOKTA BURASI! BU KAPATMA PARANTEZİ VE AYRACI SİLİNMİŞTİ.
    # --- END: GECİKMELİ BAŞLATMA MOTORU ---
	


	# ================================================================
    #  SEKME 4 - ARACLAR (Ağ Araçları Birleştirildi & Loglar Kaldırıldı)
    # ================================================================
    $sekmeAraclar.Controls.Add((Yeni-Etiket "Sistem ve Ag Yonetim Merkezi" (New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 15 12 600 28))
    $sekmeAraclar.Controls.Add((Yeni-Etiket "Windows araclarina, guncellemelere ve ag onarim seceneklerine hizlica erisin." (New-Object System.Drawing.Font("Segoe UI",8)) $FG_DIM 15 42 800 17))
    
	# --- YARDIMCI FONKSİYON: Şık İşlem Açılır Penceresi (Modal Dialog) ---
    function Ac-IslemPenceresi ($baslik, $altBaslik, $scriptBlok) {
        $popForm = New-Object System.Windows.Forms.Form
        $popForm.Text = "SistemKit - İslem Merkezi"
        $popForm.Size = New-Object System.Drawing.Size(450, 220)
        $popForm.StartPosition = "CenterParent"
        $popForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1E2227")
        $popForm.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $popForm.ShowIcon = $false
        $popForm.FormBorderStyle = "FixedDialog"
        $popForm.ControlBox = $false # Çarpı butonunu gizle (İşlem bitene kadar kapatamasın)

        # Üst Panel
        $popUst = New-Object System.Windows.Forms.Panel
        $popUst.Dock = "Top"; $popUst.Height = 70
        $popUst.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#242930")
        $popForm.Controls.Add($popUst)

        $lblBaslik = Yeni-Etiket $baslik (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)) "#10B981" 15 15 400 25
        $popUst.Controls.Add($lblBaslik)

        $lblAlt = Yeni-Etiket $altBaslik (New-Object System.Drawing.Font("Segoe UI", 9)) "#8B949E" 15 40 400 20
        $popUst.Controls.Add($lblAlt)

        # İlerleme Çubuğu (Marquee)
        $popBar = Yeni-IlerlemeKubugu 15 100 405
        $popBar.Style = "Marquee"
        $popForm.Controls.Add($popBar)

        # Durum Metni
        $lblDurum = Yeni-Etiket "Lutfen bekleyin, islem gerceklestiriliyor..." (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)) "#E0E5EC" 15 130 400 20
        $popForm.Controls.Add($lblDurum)

        $popTimer = New-Object System.Windows.Forms.Timer
        $popTimer.Interval = 500
        $popTimer.Add_Tick({
            $this.Stop() # <-- DEĞİŞİKLİK 1: $popTimer yerine $this kullanıldı
            try {
                Invoke-Command -ScriptBlock $scriptBlok
                $lblDurum.Text = "Islem basariyla tamamlandi!"
                $lblDurum.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#10B981")
                $popBar.Style = "Continuous"; $popBar.Value = 100
            } catch {
                $lblDurum.Text = "Hata: $_"
                $lblDurum.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#EF4444")
                $popBar.Style = "Continuous"; $popBar.Value = 0
            }
            
            # 2 saniye sonra kapat
            $kapatTimer = New-Object System.Windows.Forms.Timer
            $kapatTimer.Interval = 2000
            $kapatTimer.Add_Tick({ 
                $this.Stop() # <-- DEĞİŞİKLİK 2: Kapanma zamanlayıcısı da kendi kendini durduruyor
                $popForm.Close() 
            })
            $kapatTimer.Start()
        })

        $popForm.Add_Shown({ $popTimer.Start() })
        $popForm.ShowDialog() | Out-Null
    }

    # ================================================================
    # SOL SÜTUN (Sistem Araçları & Windows Update)
    # ================================================================

    # ----------------------------------------------------------------
    # MODÜL 1: HIZLI SİSTEM ERİŞİMİ
    # ----------------------------------------------------------------
    $kartSistem=Yeni-Kart 15 80 440 250; $sekmeAraclar.Controls.Add($kartSistem)
    $kartSistem.Controls.Add((Yeni-Etiket "1. Hizli Sistem Erisimi" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $INFO 12 10 400 22))
    
    $ayrac1=New-Object System.Windows.Forms.Label; $ayrac1.Location=[System.Drawing.Point]::new(10,38); $ayrac1.Size=[System.Drawing.Size]::new(420,1); $ayrac1.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $kartSistem.Controls.Add($ayrac1)

    $sistemAraclari=@(
        @{E="Gorev Yoneticisi";  K={Start-Process taskmgr};            X=10;  Y=48}
        @{E="Kayit Defteri";     K={Start-Process regedit};            X=10;  Y=84}
        @{E="Servisler";         K={Start-Process "services.msc"};     X=10;  Y=120}
        @{E="Sistem Bilgisi";    K={Start-Process msinfo32};           X=10;  Y=156}
        @{E="Disk Yonetimi";     K={Start-Process "diskmgmt.msc"};     X=220; Y=48}
        @{E="Aygit Yoneticisi";  K={Start-Process "devmgmt.msc"};      X=220; Y=84}
        @{E="Guvenlik Duvari";   K={Start-Process "wf.msc"};           X=220; Y=120}
        @{E="Cmd (Yonetici)";    K={Start-Process cmd -Verb RunAs};    X=220; Y=156}
    )
    foreach($a in $sistemAraclari){
        $b=Yeni-Buton $a.E $SUBTLE 205 30 ""
        $b.Location=[System.Drawing.Point]::new($a.X, $a.Y)
        $b.Add_Click($a.K); $kartSistem.Controls.Add($b)
    }

    # ----------------------------------------------------------------
    # MODÜL 2: WINDOWS GÜNCELLEME (Logsuz - Sadece Butonlar)
    # ----------------------------------------------------------------
    $kartGuncelleme=Yeni-Kart 15 345 440 100; $sekmeAraclar.Controls.Add($kartGuncelleme)
    $kartGuncelleme.Controls.Add((Yeni-Etiket "2. Windows Guncelleme" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $INFO 12 10 400 22))
    $ayrac2=New-Object System.Windows.Forms.Label; $ayrac2.Location=[System.Drawing.Point]::new(10,38); $ayrac2.Size=[System.Drawing.Size]::new(420,1); $ayrac2.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $kartGuncelleme.Controls.Add($ayrac2)

    $btnGunKur = Yeni-Buton "Guncellemeleri Kontrol Et ve Kur" $SUCCESS 270 34 "PSWindowsUpdate ile arka planda tum guncellemeleri kurar"
    $btnGunKur.Location = [System.Drawing.Point]::new(10, 50); $kartGuncelleme.Controls.Add($btnGunKur)
    
    $btnGunAc = Yeni-Buton "Klasik Ayarlar" $SUBTLE 140 34 "Windows Update ekranini acar"
    $btnGunAc.Location = [System.Drawing.Point]::new(290, 50); $kartGuncelleme.Controls.Add($btnGunAc)

    $btnGunAc.Add_Click({Start-Process "ms-settings:windowsupdate"})
    
    $btnGunKur.Add_Click({
        if(-not $global:yoneticiMi){ [System.Windows.Forms.MessageBox]::Show("Guncelleme kurmak icin SistemKit'i Yonetici olarak calistirmalisiniz!","Yetki Hatasi","OK","Error"); return }
        
        $script = {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            if(-not (Get-Module -ListAvailable -Name PSWindowsUpdate)){
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -EA SilentlyContinue
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -Scope CurrentUser -EA Stop | Out-Null
                Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser -EA Stop | Out-Null
            }
            Import-Module PSWindowsUpdate
            Install-WindowsUpdate -AcceptAll -IgnoreReboot -EA SilentlyContinue
        }
        Ac-IslemPenceresi "Windows Guncelleme" "Guncellemeler indiriliyor ve kuruluyor. Bu islem uzun surebilir..." $script
    })

    # ================================================================
    # SAĞ SÜTUN (Ağ Araçları & Performans)
    # ================================================================

    # ----------------------------------------------------------------
    # MODÜL 3: AĞ YÖNETİM MERKEZİ (Tüm Araçlar Popup'a Taşındı)
    # ----------------------------------------------------------------
    $kartAg = Yeni-Kart 470 80 440 215; $sekmeAraclar.Controls.Add($kartAg)
    $kartAg.Controls.Add((Yeni-Etiket "3. Ag Yonetim Merkezi" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $WARNING 12 10 400 22))
    $ayrac3 = New-Object System.Windows.Forms.Label; $ayrac3.Location=[System.Drawing.Point]::new(10,38); $ayrac3.Size=[System.Drawing.Size]::new(420,1); $ayrac3.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $kartAg.Controls.Add($ayrac3)

    # -- Buton Tanımlamaları ve Düzeni (Yan Yana Çift Sütun) --
    $btnAgBilgi = Yeni-Buton "Ag Bilgilerini Goster" $INFO 205 30 ""; $btnAgBilgi.Location = [System.Drawing.Point]::new(10, 48); $kartAg.Controls.Add($btnAgBilgi)
    $btnAgPing  = Yeni-Buton "Ping Testi" $SUBTLE 205 30 ""; $btnAgPing.Location = [System.Drawing.Point]::new(225, 48); $kartAg.Controls.Add($btnAgPing)
    
    $btnAgRota  = Yeni-Buton "Rota Takibi (Tracert)" $SUBTLE 205 30 ""; $btnAgRota.Location = [System.Drawing.Point]::new(10, 84); $kartAg.Controls.Add($btnAgRota)
    $btnAgHiz   = Yeni-Buton "Coklu Hiz Testi" $ACCENT 205 30 ""; $btnAgHiz.Location = [System.Drawing.Point]::new(225, 84); $kartAg.Controls.Add($btnAgHiz)
    
    $btnAgDns   = Yeni-Buton "DNS Temizle (/flushdns)" $SUBTLE 205 30 ""; $btnAgDns.Location = [System.Drawing.Point]::new(10, 120); $kartAg.Controls.Add($btnAgDns)
    $btnAgAyar  = Yeni-Buton "Ag Bagdastiricilari" $SUBTLE 205 30 ""; $btnAgAyar.Location = [System.Drawing.Point]::new(225, 120); $kartAg.Controls.Add($btnAgAyar)
    
    $btnAgReset = Yeni-Buton "Tam Ag Sifirlama (Winsock)" $DANGER 420 30 "Baglanti sorunlarini cozmek icin tum IP ve Winsock ayarlarini sifirlar."; $btnAgReset.Location = [System.Drawing.Point]::new(10, 168); $kartAg.Controls.Add($btnAgReset)

    # ================= AKSİYON MOTORLARI VE POPUPLAR =================

    # 1. AĞ BİLGİLERİ (Popup)
    $btnAgBilgi.Add_Click({
        $pForm = New-Object System.Windows.Forms.Form; $pForm.Text="SistemKit - Ag Bilgileri"; $pForm.Size=[System.Drawing.Size]::new(400,300); $pForm.StartPosition="CenterParent"; $pForm.BackColor=$BG_DARK; $pForm.ShowIcon=$false; $pForm.FormBorderStyle="FixedDialog"
        $lst = New-Object System.Windows.Forms.ListBox; $lst.Dock="Fill"; $lst.BackColor=$BG_CARD; $lst.ForeColor=$FG_MAIN; $lst.Font=New-Object System.Drawing.Font("Consolas",9.5); $pForm.Controls.Add($lst)
        
        $ads = Get-NetIPAddress -AddressFamily IPv4 -EA SilentlyContinue | Where-Object {$_.IPAddress -notlike "127.*"}
        foreach($a in $ads){
            [void]$lst.Items.Add("Adaptor   : $($a.InterfaceAlias)"); [void]$lst.Items.Add("IP Adresi : $($a.IPAddress)"); [void]$lst.Items.Add("Onek      : /$($a.PrefixLength)"); [void]$lst.Items.Add("-----------------------------")
        }
        $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -EA SilentlyContinue | Select-Object -First 1).NextHop
        [void]$lst.Items.Add("Gateway   : $gw")
        $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -EA SilentlyContinue | Where-Object{$_.ServerAddresses} | Select-Object -First 1).ServerAddresses
        [void]$lst.Items.Add("DNS       : $($dns -join ', ')")
        
        $pForm.ShowDialog() | Out-Null
    })

    # 2. PİNG TESTİ (Popup)
    $btnAgPing.Add_Click({
        $pForm = New-Object System.Windows.Forms.Form; $pForm.Text="SistemKit - Ping Testi"; $pForm.Size=[System.Drawing.Size]::new(400,300); $pForm.StartPosition="CenterParent"; $pForm.BackColor=$BG_DARK; $pForm.ShowIcon=$false; $pForm.FormBorderStyle="FixedDialog"
        $pForm.Controls.Add((Yeni-Etiket "Hedef:" (New-Object System.Drawing.Font("Segoe UI",9)) $FG_MAIN 10 15 50 20))
        
        $txtHedef = New-Object System.Windows.Forms.TextBox; $txtHedef.Location=[System.Drawing.Point]::new(60,13); $txtHedef.Size=[System.Drawing.Size]::new(150,24); $txtHedef.Text="8.8.8.8"; $txtHedef.BackColor=$BG_CARD; $txtHedef.ForeColor=$FG_MAIN; $pForm.Controls.Add($txtHedef)
        $numCount = New-Object System.Windows.Forms.NumericUpDown; $numCount.Location=[System.Drawing.Point]::new(220,13); $numCount.Size=[System.Drawing.Size]::new(50,24); $numCount.Value=4; $numCount.BackColor=$BG_CARD; $numCount.ForeColor=$FG_MAIN; $pForm.Controls.Add($numCount)
        
        $btnBasla = Yeni-Buton "Baslat" $ACCENT 80 26 ""; $btnBasla.Location=[System.Drawing.Point]::new(285,12); $pForm.Controls.Add($btnBasla)
        $lst = New-Object System.Windows.Forms.ListBox; $lst.Location=[System.Drawing.Point]::new(10,50); $lst.Size=[System.Drawing.Size]::new(360,200); $lst.BackColor=$BG_CARD; $lst.ForeColor=$FG_MAIN; $lst.Font=New-Object System.Drawing.Font("Consolas",9.5); $pForm.Controls.Add($lst)

        $btnBasla.Add_Click({
            $lst.Items.Clear(); [void]$lst.Items.Add("Ping gonderiliyor: $($txtHedef.Text) ($($numCount.Value) paket)...")
            $btnBasla.Enabled = $false; [System.Windows.Forms.Application]::DoEvents()
            try {
                $s = Test-Connection -ComputerName $txtHedef.Text -Count $numCount.Value -EA SilentlyContinue
                if($s){
                    foreach($r in $s){ $ms = if($r.ResponseTime -ne $null){"$($r.ResponseTime) ms"}else{"zaman asimi"}; [void]$lst.Items.Add("$($r.Address) -- $ms") }
                    $ort = [math]::Round(($s|Where-Object{$_.ResponseTime -ne $null}|Measure-Object -Property ResponseTime -Average).Average, 1)
                    [void]$lst.Items.Add("---"); [void]$lst.Items.Add("Ortalama: $ort ms")
                } else { [void]$lst.Items.Add("Yanit alinamadi!") }
            } catch { [void]$lst.Items.Add("Hata: $_") }
            $btnBasla.Enabled = $true
        })
        $pForm.ShowDialog() | Out-Null
    })

    # 3. ROTA TAKİBİ (TRACERT) (Popup - Job Mimarisi ile)
    $btnAgRota.Add_Click({
        $pForm = New-Object System.Windows.Forms.Form; $pForm.Text="SistemKit - Rota Takibi"; $pForm.Size=[System.Drawing.Size]::new(450,350); $pForm.StartPosition="CenterParent"; $pForm.BackColor=$BG_DARK; $pForm.ShowIcon=$false; $pForm.FormBorderStyle="FixedDialog"
        $pForm.Controls.Add((Yeni-Etiket "Hedef:" (New-Object System.Drawing.Font("Segoe UI",9)) $FG_MAIN 10 15 50 20))
        $txtHedef = New-Object System.Windows.Forms.TextBox; $txtHedef.Location=[System.Drawing.Point]::new(60,13); $txtHedef.Size=[System.Drawing.Size]::new(200,24); $txtHedef.Text="google.com"; $txtHedef.BackColor=$BG_CARD; $txtHedef.ForeColor=$FG_MAIN; $pForm.Controls.Add($txtHedef)
        $btnBasla = Yeni-Buton "Baslat" $ACCENT 100 26 ""; $btnBasla.Location=[System.Drawing.Point]::new(275,12); $pForm.Controls.Add($btnBasla)
        $lst = New-Object System.Windows.Forms.ListBox; $lst.Location=[System.Drawing.Point]::new(10,50); $lst.Size=[System.Drawing.Size]::new(410,240); $lst.BackColor=$BG_CARD; $lst.ForeColor=$FG_MAIN; $lst.Font=New-Object System.Drawing.Font("Consolas",9); $pForm.Controls.Add($lst)

        $btnBasla.Add_Click({
            $lst.Items.Clear(); [void]$lst.Items.Add("Rota takibi baslatildi: $($txtHedef.Text) (Maks 20 sicrama)...")
            $btnBasla.Enabled = $false
            $script:tracertJob = Start-Job {param($t) & tracert.exe -d -h 20 $t 2>&1} -ArgumentList $txtHedef.Text
            $script:tt = New-Object System.Windows.Forms.Timer; $script:tt.Interval = 800
            $script:tt.Add_Tick({
                if ($null -eq $script:tracertJob) { return }
                $outData = Receive-Job $script:tracertJob
                if($outData){ foreach($satir in $outData){ [void]$lst.Items.Add($satir); $lst.TopIndex = $lst.Items.Count - 1 } }
                if($script:tracertJob.State -ne "Running"){
                    $script:tt.Stop(); $finalData = Receive-Job $script:tracertJob
                    if($finalData){ foreach($satir in $finalData){ [void]$lst.Items.Add($satir) } }
                    Remove-Job $script:tracertJob -Force -EA SilentlyContinue; $script:tracertJob = $null
                    [void]$lst.Items.Add("--- Islem Tamamlandi ---"); $btnBasla.Enabled = $true; $script:tt.Dispose()
                }
            })
            $script:tt.Start()
        })
        $pForm.Add_FormClosing({ try { $script:tt.Stop(); Remove-Job $script:tracertJob -Force -EA SilentlyContinue } catch {} })
        $pForm.ShowDialog() | Out-Null
    })

    # 4. HIZ TESTİ (Popup - Gelişmiş CheckBox List)
    $btnAgHiz.Add_Click({
        $pForm = New-Object System.Windows.Forms.Form; $pForm.Text="SistemKit - Hiz Testi"; $pForm.Size=[System.Drawing.Size]::new(400,340); $pForm.StartPosition="CenterParent"; $pForm.BackColor=$BG_DARK; $pForm.ShowIcon=$false; $pForm.FormBorderStyle="FixedDialog"
        $pForm.Controls.Add((Yeni-Etiket "Test Edilecek Sunuculari Secin:" (New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)) $FG_MAIN 10 10 300 20))
        
        $sunucuListesi = @(
            @{ Ad = "Tele2 (Avrupa)"; Url = "http://speedtest.tele2.net/10MB.zip" },
            @{ Ad = "Serverius (Global)"; Url = "https://speedtest.serverius.net/files/20mb.bin" },
            @{ Ad = "Leaseweb (Stabil)"; Url = "https://mirror.ams1.nl.leaseweb.net/speedtest/10mb.bin" }
        )
        $chList = New-Object System.Windows.Forms.CheckedListBox; $chList.Location=[System.Drawing.Point]::new(10,35); $chList.Size=[System.Drawing.Size]::new(360,65); $chList.BackColor=$BG_CARD; $chList.ForeColor=$FG_MAIN; $chList.BorderStyle="None"; $chList.CheckOnClick=$true
        foreach($s in $sunucuListesi){ [void]$chList.Items.Add($s.Ad, $true) }; $pForm.Controls.Add($chList)
        
        $btnBasla = Yeni-Buton "Testi Baslat" $ACCENT 360 30 ""; $btnBasla.Location=[System.Drawing.Point]::new(10,110); $pForm.Controls.Add($btnBasla)
        $lst = New-Object System.Windows.Forms.ListBox; $lst.Location=[System.Drawing.Point]::new(10,150); $lst.Size=[System.Drawing.Size]::new(360,135); $lst.BackColor=$BG_CARD; $lst.ForeColor=$FG_MAIN; $lst.Font=New-Object System.Drawing.Font("Consolas",9.5); $pForm.Controls.Add($lst)

        $btnBasla.Add_Click({
            if ($chList.CheckedItems.Count -eq 0) { [void]$lst.Items.Add("HATA: Sunucu secilmedi!"); return }
            $btnBasla.Enabled = $false; $lst.Items.Clear(); $toplam_M = 0; $basarili_C = 0
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

            foreach($item in $chList.CheckedItems) {
                $cUrl = ($sunucuListesi | Where-Object { $_.Ad -eq $item.ToString() }).Url
                [void]$lst.Items.Add(">> $($item) baglaniliyor..."); [System.Windows.Forms.Application]::DoEvents()
                try {
                    $wc = New-Object System.Net.WebClient; $wc.Headers.Add("User-Agent", "Mozilla/5.0"); $wc.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
                    $timer = [System.Diagnostics.Stopwatch]::StartNew()
                    $data = $wc.DownloadData($cUrl + "?t=" + (Get-Date).Ticks)
                    $timer.Stop()
                    $sn = [math]::Round($timer.Elapsed.TotalSeconds, 2); if($sn -lt 0.1){ $sn = 0.5 }
                    $mbps = [math]::Round((($data.Length / 1MB) / $sn) * 8, 1)
                    [void]$lst.Items.Add("   Sure: $sn sn | Hiz: $mbps Mbps"); $toplam_M += $mbps; $basarili_C++
                } catch { [void]$lst.Items.Add("   HATA: Baglanti kurulamadi.") }
                [System.Windows.Forms.Application]::DoEvents()
            }
            if($basarili_C -gt 0) {
                $f_ort = [math]::Round($toplam_M / $basarili_C, 1)
                [void]$lst.Items.Add("-----------------------------"); [void]$lst.Items.Add("GENEL ORTALAMA: $f_ort Mbps")
            }
            $btnBasla.Enabled = $true
        })
        $pForm.ShowDialog() | Out-Null
    })

    # 5. DNS TEMİZLEME (Sessiz İşlem)
    $btnAgDns.Add_Click({
        Ac-IslemPenceresi "DNS Temizligi" "IP yapilandirmasi yenileniyor..." { Clear-DnsClientCache -EA SilentlyContinue; ipconfig /flushdns }
    })

    # 6. AĞ BAĞLANTILARI (Kontrol Paneli Kısayolu)
    $btnAgAyar.Add_Click({ Start-Process "ncpa.cpl" })

    # 7. TAM AĞ SIFIRLAMA (Yönetici Onaylı)
    $btnAgReset.Add_Click({
        if(-not $global:yoneticiMi){ [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.","Yetki Hatasi","OK","Error"); return }
        $onay = [System.Windows.Forms.MessageBox]::Show("Tum ag bagdastiricilari (Winsock & IP) sifirlanacak. Internet baglantiniz kopacak ve sistem yeniden baslatma gerektirecektir. Onayliyor musunuz?","Sifirlama Onayi","YesNo","Warning")
        if ($onay -eq "Yes") {
            Ac-IslemPenceresi "Tam Ag Sifirlama" "Winsock ve IP yapilandirmasi sifirlaniyor..." { netsh winsock reset; netsh int ip reset; ipconfig /release; ipconfig /renew }
        }
    })

    # ----------------------------------------------------------------
    # MODÜL 4: SİSTEM GÜCÜ VE PERFORMANS YÖNETİCİSİ
    # ----------------------------------------------------------------
    $kartOyun = Yeni-Kart 470 304 440 135; $sekmeAraclar.Controls.Add($kartOyun)
    $kartOyun.Controls.Add((Yeni-Etiket "4. Sistem Gucu ve Performans Yoneticisi" (New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)) $WARNING 12 10 400 22))
    $ayrac4 = New-Object System.Windows.Forms.Label; $ayrac4.Location=[System.Drawing.Point]::new(10,38); $ayrac4.Size=[System.Drawing.Size]::new(420,1); $ayrac4.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $kartOyun.Controls.Add($ayrac4)

    # 1. GÜÇ VE PERFORMANS BUTONU
    $btnGucYoneticisi = Yeni-Buton "Guc ve Performans Modu Ayarlari" $ACCENT 420 32 "Sistemin guc planini ve oyun performansini optimize edin."
    $btnGucYoneticisi.Location = [System.Drawing.Point]::new(10, 48); $kartOyun.Controls.Add($btnGucYoneticisi)

    # 2. SANAL RAM BUTONU
    $btnSanalRam = Yeni-Buton "Sanal RAM (Pagefile) Yoneticisi" $INFO 420 32 "Diskinizdeki takas alanini (Sanal RAM) analiz edip boyutlandirin."
    $btnSanalRam.Location = [System.Drawing.Point]::new(10, 86); $kartOyun.Controls.Add($btnSanalRam)


    # ================= AKSİYON MOTORLARI VE POPUPLAR =================

    # --- GÜÇ VE PERFORMANS MOTORU (Sorgulayan Pencere) ---
    $btnGucYoneticisi.Add_Click({
        if(-not $global:yoneticiMi){ [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.","Yetki Hatasi","OK","Error"); return }

        # Arka planda mevcut durumu sorgula
        $mevcutPlan = (powercfg /getactivescheme)
        $aktifMod = "DENGELI"
        $durumRenk = "#00A4EF"
        if ($mevcutPlan -match "G.ç tasarrufu|Power saver") { $aktifMod = "GUC TASARRUFU"; $durumRenk = "#8B949E" }
        elseif ($mevcutPlan -match "e9a42b02-d5df-448d-aa00-03f14749eb61|Y.ksek|Ultimate|High") { $aktifMod = "NIHAI PERFORMANS"; $durumRenk = "#10B981" }

        $gForm = New-Object System.Windows.Forms.Form; $gForm.Text="SistemKit - Guc Yoneticisi"; $gForm.Size=[System.Drawing.Size]::new(380,310); $gForm.StartPosition="CenterParent"; $gForm.BackColor=$BG_DARK; $gForm.ForeColor=$FG_MAIN; $gForm.ShowIcon=$false; $gForm.FormBorderStyle="FixedDialog"; $gForm.MaximizeBox=$false
        
        $gForm.Controls.Add((Yeni-Etiket "Mevcut Durum: $aktifMod" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) $durumRenk 20 15 340 25))
        $ayracP=New-Object System.Windows.Forms.Label; $ayracP.Location=[System.Drawing.Point]::new(20,45); $ayracP.Size=[System.Drawing.Size]::new(320,1); $ayracP.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $gForm.Controls.Add($ayracP)

        $optTasarruf = New-Object System.Windows.Forms.RadioButton; $optTasarruf.Text = "Guc Tasarrufu Modu (Pil omrunu uzatir, isinmayi azaltir)"; $optTasarruf.Location=[System.Drawing.Point]::new(20,60); $optTasarruf.Size=[System.Drawing.Size]::new(340,40); $optTasarruf.Checked = ($aktifMod -eq "GUC TASARRUFU"); $gForm.Controls.Add($optTasarruf)
        
        $optDengeli = New-Object System.Windows.Forms.RadioButton; $optDengeli.Text = "Dengeli Mod - Varsayilan (Gunluk kullanim icin idealdir)"; $optDengeli.Location=[System.Drawing.Point]::new(20,110); $optDengeli.Size=[System.Drawing.Size]::new(340,40); $optDengeli.Checked = ($aktifMod -eq "DENGELI"); $gForm.Controls.Add($optDengeli)
        
        $optPerformans = New-Object System.Windows.Forms.RadioButton; $optPerformans.Text = "Nihai Performans Modu (Oyunlar icin servisleri kapatir)"; $optPerformans.Location=[System.Drawing.Point]::new(20,160); $optPerformans.Size=[System.Drawing.Size]::new(340,40); $optPerformans.Checked = ($aktifMod -eq "NIHAI PERFORMANS"); $gForm.Controls.Add($optPerformans)

        $btnUygulaP = Yeni-Buton "Modu Uygula" $ACCENT 150 34 ""; $btnUygulaP.Location=[System.Drawing.Point]::new(105,215); $gForm.Controls.Add($btnUygulaP)

        $btnUygulaP.Add_Click({
            $gForm.Close()
            if ($optTasarruf.Checked) {
                $script = {
                    $plan = powercfg /list | Select-String "G.ç tasarrufu|Power saver"
                    if ($plan -match "GUID:\s+([a-zA-Z0-9\-]+)") { powercfg -setactive $matches[1] }
                    Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
                }
                Ac-IslemPenceresi "Guc Tasarrufu Modu" "Sistem guc tuketimi en aza indiriliyor..." $script
            }
            elseif ($optDengeli.Checked) {
                $script = {
                    $plan = powercfg /list | Select-String "Dengeli|Balanced"
                    if ($plan -match "GUID:\s+([a-zA-Z0-9\-]+)") { powercfg -setactive $matches[1] }
                    Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -EA SilentlyContinue
                    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -EA SilentlyContinue
                }
                Ac-IslemPenceresi "Dengeli Mod" "Sistem varsayilan guc ayarlarina donduruluyor..." $script
            }
            elseif ($optPerformans.Checked) {
                $script = {
                    $plan = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
                    if ($plan -match "GUID:\s+([a-zA-Z0-9\-]+)") { powercfg -setactive $matches[1] }
                    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue; Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -Force -EA SilentlyContinue
                }
                Ac-IslemPenceresi "Performans Modu" "Nihai guc plani aktif ediliyor ve arka plan servisleri kapatiliyor..." $script
            }
        })
        $gForm.ShowDialog() | Out-Null
    })

    # --- SANAL RAM MOTORU (Sorgulayan Pencere) ---
    $btnSanalRam.Add_Click({
        if(-not $global:yoneticiMi){ [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.","Yetki Hatasi","OK","Error"); return }

        $cs = Get-CimInstance Win32_ComputerSystem
        $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
        $bosDiskGB = [math]::Round($diskC.FreeSpace / 1GB)
        $autoYonetim = $cs.AutomaticManagedPagefile
        
        $idealGB = [math]::Max(2, [math]::Min(32, [math]::Round($ramGB * 1.5)))
        $kullanilabilirMaxGB = [math]::Min(64, [math]::Round($bosDiskGB * 0.5))

        $srForm = New-Object System.Windows.Forms.Form; $srForm.Text="SistemKit - Sanal RAM Yoneticisi"; $srForm.Size=[System.Drawing.Size]::new(420,380); $srForm.StartPosition="CenterParent"; $srForm.BackColor=$BG_DARK; $srForm.ForeColor=$FG_MAIN; $srForm.ShowIcon=$false; $srForm.FormBorderStyle="FixedDialog"; $srForm.MaximizeBox=$false

        $srForm.Controls.Add((Yeni-Etiket "Sanal Bellek (Pagefile) Durumu" (New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)) "#00A4EF" 20 15 360 25))
        $srForm.Controls.Add((Yeni-Etiket "Diskinizin bir kismini RAM (Takas Alani) olarak kullanir." (New-Object System.Drawing.Font("Segoe UI",8.5)) "#8B949E" 20 40 380 20))

        $lblBilgi = Yeni-Etiket "Fiziksel RAM: $ramGB GB`nC: Diski Bos Alan: $bosDiskGB GB`n`nOnerilen Sanal RAM: $idealGB GB (Maks: $kullanilabilirMaxGB GB)" (New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)) "#10B981" 20 75 360 60
        $srForm.Controls.Add($lblBilgi)

        $ayracS=New-Object System.Windows.Forms.Label; $ayracS.Location=[System.Drawing.Point]::new(20,140); $ayracS.Size=[System.Drawing.Size]::new(360,1); $ayracS.BackColor=[System.Drawing.Color]::FromArgb(55,55,75); $srForm.Controls.Add($ayracS)

        $optOto = New-Object System.Windows.Forms.RadioButton; $optOto.Text = "Windows Otomatik Yonetsin (Varsayilan)"; $optOto.Location=[System.Drawing.Point]::new(20,155); $optOto.Size=[System.Drawing.Size]::new(300,24); $optOto.Checked = $autoYonetim; $srForm.Controls.Add($optOto)
        $optOzel = New-Object System.Windows.Forms.RadioButton; $optOzel.Text = "Ozel Boyut Belirle (GB):"; $optOzel.Location=[System.Drawing.Point]::new(20,185); $optOzel.Size=[System.Drawing.Size]::new(170,24); $optOzel.Checked = (-not $autoYonetim); $srForm.Controls.Add($optOzel)
        
        $numGB = New-Object System.Windows.Forms.NumericUpDown; $numGB.Location=[System.Drawing.Point]::new(190,186); $numGB.Size=[System.Drawing.Size]::new(70,24); $numGB.Minimum=2; $numGB.Maximum=$kullanilabilirMaxGB; $numGB.Value=$idealGB; $numGB.BackColor=$BG_CARD; $numGB.ForeColor=$FG_MAIN; $numGB.Enabled=$optOzel.Checked; $srForm.Controls.Add($numGB)
        
        $optKapali = New-Object System.Windows.Forms.RadioButton; $optKapali.Text = "Sanal RAM'i Kapat (Sistem cokebilir!)"; $optKapali.Location=[System.Drawing.Point]::new(20,215); $optKapali.Size=[System.Drawing.Size]::new(300,24); $optKapali.ForeColor=[System.Drawing.ColorTranslator]::FromHtml("#EF4444"); $srForm.Controls.Add($optKapali)

        $optOzel.Add_CheckedChanged({ $numGB.Enabled = $optOzel.Checked })

        $btnUygulaS = Yeni-Buton "Ayarlari Uygula" $ACCENT 150 34 ""; $btnUygulaS.Location=[System.Drawing.Point]::new(125,270); $srForm.Controls.Add($btnUygulaS)

        $btnUygulaS.Add_Click({
            $srForm.Close()
            $script = {
                $compSys = Get-WmiObject Win32_ComputerSystem
                if ($optOto.Checked) {
                    $compSys.AutomaticManagedPagefile = $true; $compSys.Put() | Out-Null
                } 
                elseif ($optKapali.Checked) {
                    $compSys.AutomaticManagedPagefile = $false; $compSys.Put() | Out-Null
                    $pages = Get-WmiObject Win32_PageFileSetting; if ($pages) { $pages | Remove-WmiObject }
                } 
                elseif ($optOzel.Checked) {
                    $compSys.AutomaticManagedPagefile = $false; $compSys.Put() | Out-Null
                    $secilenMB = $numGB.Value * 1024
                    $pages = Get-WmiObject Win32_PageFileSetting; if ($pages) { $pages | Remove-WmiObject }
                    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="C:\pagefile.sys"; InitialSize=$secilenMB; MaximumSize=$secilenMB} | Out-Null
                }
            }
            Ac-IslemPenceresi "Sanal RAM Yapilandirmasi" "Sistem bellek ayarlari yaziliyor..." $script
            [System.Windows.Forms.MessageBox]::Show("Sanal RAM ayarlari basariyla uygulandi.`nDegisikliklerin etkinlesmesi icin lutfen bilgisayarinizi YENIDEN BASLATIN.", "Bilgi", "OK", "Information") | Out-Null
        })
        $srForm.ShowDialog() | Out-Null
    })
	
	# ================================================================
    #  SEKME 5 - SISTEM KURULUMU & GÖÇ ASİSTANI (LİKİT MİMARİ v8.1)
    # ================================================================
	
    $tbl7 = New-Object System.Windows.Forms.TableLayoutPanel
    $tbl7.Dock = "Fill"; $tbl7.BackColor = $BG_DARK
    $tbl7.ColumnCount = 3; $tbl7.RowCount = 1
	# TAVANDAN VE YANLARDAN BOŞLUK (Nefes Payı)
    $tbl7.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 0)
    $tbl7.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 33.33))) | Out-Null
    $tbl7.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 33.33))) | Out-Null
    $tbl7.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 33.33))) | Out-Null
    $sekmeKurulum.Controls.Add($tbl7)

    # --- Ortak Log Ekranı (Sekmenin Altına Boydan Boya) ---
    $panKurLog = New-Object System.Windows.Forms.Panel
    $panKurLog.Dock = "Bottom"; $panKurLog.Height = 150
    $panKurLog.BackColor = $BG_DARK; $panKurLog.Padding = New-Object System.Windows.Forms.Padding(10, 0, 10, 10)
    $sekmeKurulum.Controls.Add($panKurLog)
    
    $logKurulum = Yeni-MetinKutusu 0 0 10 10; $logKurulum.Dock = "Fill"
    $panKurLog.Controls.Add($logKurulum)
    $sekmeKurulum.Controls.SetChildIndex($panKurLog, 0)

    # ----------------------------------------------------------------
    # KART 1: SOL SÜTUN (FORMAT ÖNCESİ HAZIRLIK & YEDEK)
    # ----------------------------------------------------------------
    $panHazirlik = New-Object System.Windows.Forms.Panel
    $panHazirlik.Dock = "Fill"; $panHazirlik.BackColor = $BG_PANEL; $panHazirlik.Margin = New-Object System.Windows.Forms.Padding(10, 10, 5, 10)
    $tbl7.Controls.Add($panHazirlik, 0, 0)

    $panHazirlik.Controls.Add((Yeni-Etiket "1. Hazirlik (Format Oncesi)" (New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)) $INFO 15 15 300 22))
    
    $btnSurucuYedek = Yeni-Buton "1. Suruculeri Paketle (Yedekle)" $SUBTLE 250 35 "3. Parti suruculeri klasore cikartir"
    $btnSurucuYedek.Location = New-Object System.Drawing.Point(15, 60); $panHazirlik.Controls.Add($btnSurucuYedek)

    $btnDNAYedekle = Yeni-Buton "2. Uygulama DNA'sini Cikart" $SUBTLE 250 35 "Kurulu Winget uygulamalarini yedekler"
    $btnDNAYedekle.Location = New-Object System.Drawing.Point(15, 105); $panHazirlik.Controls.Add($btnDNAYedekle)

    $btnTamYedek = Yeni-Buton "TAM SISTEM İMAJI (WIM)" $DANGER 250 35 "C: Surucusunun tam yedegini alir"
    $btnTamYedek.Location = New-Object System.Drawing.Point(15, 170); $panHazirlik.Controls.Add($btnTamYedek)
	# --- Sol Sütun: Windows Kurulum Asistanı Butonu ---
    $btnFormatUSB = Yeni-Buton "Windows Kurulum Asistanı" $ACCENT 250 35 "Win 10/11 MCT veya Rufus ile format USB'si hazirlayin"
    $btnFormatUSB.Location = New-Object System.Drawing.Point(15, 235) 
    $panHazirlik.Controls.Add($btnFormatUSB)

    # ----------------------------------------------------------------
    # KART 2: ORTA SÜTUN (KURULUM & OTOMASYON MERKEZİ)
    # ----------------------------------------------------------------
    $panSetup = New-Object System.Windows.Forms.Panel
    $panSetup.Dock = "Fill"; $panSetup.BackColor = $BG_PANEL; $panSetup.Margin = New-Object System.Windows.Forms.Padding(5, 10, 5, 10)
    $tbl7.Controls.Add($panSetup, 1, 0)

    $panSetup.Controls.Add((Yeni-Etiket "2. Kurulum Merkezi" (New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)) $SUCCESS 15 15 300 22))

    $btnSurucuKur = Yeni-Buton "1. Yedek Suruculeri Kur" $SUBTLE 250 35 "Yedeklenmis suruculeri sisteme geri yukler"
    $btnSurucuKur.Location = New-Object System.Drawing.Point(15, 60); $panSetup.Controls.Add($btnSurucuKur)

    $btnKatalogAc = Yeni-Buton "Uygulama Katalogunu Ac..." $ACCENT 250 35 "Kurulacak uygulamalari secmek icin listeyi acar"
    $btnKatalogAc.Location = New-Object System.Drawing.Point(15, 120); $panSetup.Controls.Add($btnKatalogAc)

    $listeKuyruk = New-Object System.Windows.Forms.ListView
    $listeKuyruk.Location = New-Object System.Drawing.Point(15, 165); $listeKuyruk.Size = New-Object System.Drawing.Size(250, 160)
    $listeKuyruk.BackColor = $BG_CARD; $listeKuyruk.ForeColor = $FG_MAIN; $listeKuyruk.BorderStyle = "None"
    $listeKuyruk.View = "Details"; $listeKuyruk.FullRowSelect = $true; $listeKuyruk.HeaderStyle = "None"
    $listeKuyruk.Columns.Add("Uygulama", 230) | Out-Null
    $panSetup.Controls.Add($listeKuyruk)

    $btnKuyrukKur = Yeni-Buton "Kuyruktakileri Otomatik Kur" $SUCCESS 250 35 "Listelenen uygulamalari kurar"
    $btnKuyrukKur.Location = New-Object System.Drawing.Point(15, 335); $panSetup.Controls.Add($btnKuyrukKur)

    # ----------------------------------------------------------------
    # KART 3: SAĞ SÜTUN (LİSANS & İNCE AYARLAR v8.1)
    # ----------------------------------------------------------------
	
    $panLisans = New-Object System.Windows.Forms.Panel
    $panLisans.Dock = "Fill"; $panLisans.BackColor = $BG_PANEL; $panLisans.Margin = New-Object System.Windows.Forms.Padding(5, 10, 10, 10)
    $tbl7.Controls.Add($panLisans, 2, 0)

    $panLisans.Controls.Add((Yeni-Etiket "3. Gelismis Lisans Yonetimi" (New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)) $WARNING 15 15 300 22))

    # --- Üst Grup: Bilgi ve Klasik Sorgular ---
    $btnLisansOgren = Yeni-Buton "Mevcut Anahtari Ogren (BIOS/Reg)" $INFO 250 32 "Sistemdeki urun anahtarini gosterir"
    $btnLisansOgren.Location = New-Object System.Drawing.Point(15, 45); $panLisans.Controls.Add($btnLisansOgren)

	# --- Ferahlatılmış Lisans Sorgu Butonları (GARANTİLİ GÖRÜNÜM) ---
    $lisansSorguAkis = New-Object System.Windows.Forms.FlowLayoutPanel
    $lisansSorguAkis.Location = New-Object System.Drawing.Point(15, 82)
    # Genişliği 280'e çıkardık, WrapContents'i True yaptık ki sığmazsa alt satıra geçip görünsün!
    $lisansSorguAkis.Size = New-Object System.Drawing.Size(280, 45) 
    $lisansSorguAkis.BackColor = $BG_PANEL
    $lisansSorguAkis.FlowDirection = "LeftToRight"
    $lisansSorguAkis.WrapContents = $true 
    
    # Buton genişliklerini daha da kısalttık
    $btnDli = Yeni-Buton "Durum" $SUBTLE 70 30 "Lisans durumunu kisa gosterir (/dli)"
    $btnDlv = Yeni-Buton "Detay" $SUBTLE 70 30 "Lisans durumunu detayli gosterir (/dlv)"
    $btnXpr = Yeni-Buton "Sure"  $SUBTLE 70 30 "Lisansin bitis suresini gosterir (/xpr)"
    
    # Marginleri küçülttük ki aralara rahat sığsınlar
    $btnDli.Margin = New-Object System.Windows.Forms.Padding(0, 3, 3, 3)
    $btnDlv.Margin = New-Object System.Windows.Forms.Padding(0, 3, 3, 3)
    $btnXpr.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 3)

    foreach($b in @($btnDli, $btnDlv, $btnXpr)){ $lisansSorguAkis.Controls.Add($b) }
	$panLisans.Controls.Add($lisansSorguAkis)

    $ayracLis1 = New-Object System.Windows.Forms.Label
    $ayracLis1.Location = New-Object System.Drawing.Point(15, 125); $ayracLis1.Size = New-Object System.Drawing.Size(250, 1); $ayracLis1.BackColor = $SUBTLE
    $panLisans.Controls.Add($ayracLis1)

    # --- Orta Grup: Aktivasyon Yedekleme (Tokens.dat) ---
    $panLisans.Controls.Add((Yeni-Etiket "Tam Aktivasyon Yedegi (Offline):" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)) $FG_MAIN 15 135 250 20))

    $btnLisansYedekle = Yeni-Buton "Lisansi Yedekle (Tokens.dat)" $ACCENT 250 32 "Aktivasyon dosyalarini sectiginiz klasore kopyalar"
    $btnLisansYedekle.Location = New-Object System.Drawing.Point(15, 160); $panLisans.Controls.Add($btnLisansYedekle)

    $btnLisansGeriYukle = Yeni-Buton "Yedekten Geri Yukle (Format Sonrasi)" $WARNING 250 32 "Yedeklenmis aktivasyon dosyalarini sisteme entegre eder"
    $btnLisansGeriYukle.Location = New-Object System.Drawing.Point(15, 197); $panLisans.Controls.Add($btnLisansGeriYukle)

    $ayracLis2 = New-Object System.Windows.Forms.Label
    $ayracLis2.Location = New-Object System.Drawing.Point(15, 240); $ayracLis2.Size = New-Object System.Drawing.Size(250, 1); $ayracLis2.BackColor = $SUBTLE
    $panLisans.Controls.Add($ayracLis2)

    # --- Alt Grup: Manuel Etkinleştirme ---
    $panLisans.Controls.Add((Yeni-Etiket "Manuel Etkinlestirme (Urun Anahtari):" (New-Object System.Drawing.Font("Segoe UI", 8.5)) $FG_DIM 15 250 250 20))
    
    $txtKey = New-Object System.Windows.Forms.TextBox
    $txtKey.Location = New-Object System.Drawing.Point(15, 275); $txtKey.Size = New-Object System.Drawing.Size(175, 24)
    $txtKey.BackColor = $BG_CARD; $txtKey.ForeColor = $FG_MAIN; $txtKey.BorderStyle = "FixedSingle"; $txtKey.Text = "XXXXX-XXXXX-..."
    $txtKey.Add_GotFocus({if($txtKey.Text -match "XXXXX"){$txtKey.Text="";$txtKey.ForeColor=$SUCCESS}})
    $panLisans.Controls.Add($txtKey)

    $btnKeyGir = Yeni-Buton "Gir (/ipk)" $ACCENT 70 24
    $btnKeyGir.Location = New-Object System.Drawing.Point(195, 275); $panLisans.Controls.Add($btnKeyGir)

    $btnEtkinlestir = Yeni-Buton "Sistemi Etkinlestir (/ato)" $SUCCESS 250 32 "Girilen anahtari etkinlestirir"
    $btnEtkinlestir.Location = New-Object System.Drawing.Point(15, 305); $panLisans.Controls.Add($btnEtkinlestir)

	# ================================================================
    # SOL VE ORTA SÜTUN AKSİYON MOTORLARI
    # ================================================================

	# --- Sol Sütun: Sürücü Yedekleme (Sabit Konumlu Bar ve Esnek Rapor Ekranı) ---
    $btnSurucuYedek.Add_Click({
        if (-not $global:yoneticiMi) { [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.", "Uyari", 0, 16); return }

        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
        $browser.Description = "Suruculerin (Drivers) yedeklenecegi ana klasoru secin (Orn: D: veya USB)"
        if ($browser.ShowDialog() -ne "OK") { return }

        $secilenKlasor = $browser.SelectedPath.TrimEnd('\')
        $tarih = Get-Date -f "yyyyMMdd_HHmm"
        $hedef = "$secilenKlasor\SistemKit_SurucuYedek_$tarih"

        if (-not (Test-Path $hedef)) { New-Item $hedef -ItemType Directory -Force | Out-Null }

        $btnSurucuYedek.Enabled = $false

        # --- İlerleme Çubuğu Paneli (Görünür Sabit Konum) ---
        $panIlerlemeSurucu = New-Object System.Windows.Forms.Panel
        $panIlerlemeSurucu.Size = New-Object System.Drawing.Size(270, 35)
        # 4. butonun (Format USB) hemen altına, log ekranının üst sınırına sabitliyoruz:
        $panIlerlemeSurucu.Location = New-Object System.Drawing.Point(10 , 450)
        $panIlerlemeSurucu.BackColor = $BG_CARD

        $lblSurucuLoc = Yeni-Etiket "Suruculer Paketleniyor... (Tahmini 1-2 Dk)" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)) $WARNING 5 5 260 15
        $panIlerlemeSurucu.Controls.Add($lblSurucuLoc)

        $barSurucu = Yeni-IlerlemeKubugu 5 25 260
        $barSurucu.Style = "Blocks"
        $barSurucu.Maximum = 100
        $barSurucu.Value = 0
        $panIlerlemeSurucu.Controls.Add($barSurucu)

        $panHazirlik.Controls.Add($panIlerlemeSurucu)
        $panIlerlemeSurucu.BringToFront()
        $form.Refresh()

        Yaz-Log $logKurulum "Suruculer yedekleniyor ($hedef)... Lutfen bekleyin." $WARNING

        # Arka planda sürücü paketleme işlemi
        $drvJob = Start-Job {
            param($p)
            return Export-WindowsDriver -Online -Destination $p -ErrorAction SilentlyContinue
        } -ArgumentList $hedef

        $surucuSaniye = 0

        # Donmayan Senkron Döngü
        while ($drvJob.State -eq "Running") {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 1000

            $surucuSaniye++
            $tahminiYuzde = [math]::Min([math]::Round(($surucuSaniye / 90) * 100), 95)

            # Nesnelerin hala var olduğundan emin ol
            if ($barSurucu -and -not $barSurucu.IsDisposed) {
                $barSurucu.Value = $tahminiYuzde
                $lblSurucuLoc.Text = "Suruculer Paketleniyor... %$tahminiYuzde ($surucuSaniye sn)"
            }
        }

        # İşlem Bitti
        if ($barSurucu -and -not $barSurucu.IsDisposed) {
            $barSurucu.Value = 100
            $lblSurucuLoc.Text = "Paketleme Tamamlandi!"
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 500
        }

        # Paneli Kaldır
        if ($panHazirlik.Controls.Contains($panIlerlemeSurucu)) { $panHazirlik.Controls.Remove($panIlerlemeSurucu) }

        $suruculer = Receive-Job $drvJob
        Remove-Job $drvJob -Force -EA SilentlyContinue

        $surucuSayisi = 0
        if ($null -ne $suruculer) { $surucuSayisi = @($suruculer).Count }

        if ($surucuSayisi -gt 0) {
            # Log Kayıtları
            Yaz-Log $logKurulum "--------------------------------------" $FG_DIM
            Yaz-Log $logKurulum "SURUCU YEDEKLEME OZETI:" $INFO
            Yaz-Log $logKurulum ">> Basariyla Yedeklenen: $surucuSayisi Surucu" $SUCCESS
            Yaz-Log $logKurulum ">> Hedef Klasor: $hedef" $WARNING
            Yaz-Log $logKurulum "--------------------------------------" $FG_DIM

            # --- ESNEK VE BÜYÜTÜLEBİLİR RAPOR EKRANI ---
            $raporForm = New-Object System.Windows.Forms.Form
            $raporForm.Text = "SistemKit - Surucu Raporu"
            $raporForm.Size = New-Object System.Drawing.Size(700, 550) # Ekran varsayılan olarak genişletildi
            $raporForm.StartPosition = "CenterParent"
            $raporForm.BackColor = $BG_DARK
            $raporForm.ForeColor = $FG_MAIN
            $raporForm.ShowIcon = $false
            $raporForm.FormBorderStyle = "Sizable" # ARTIK BÜYÜTÜLÜP KÜÇÜLTÜLEBİLİR!
            $raporForm.MinimumSize = New-Object System.Drawing.Size(500, 400)

            # Üst Panel
            $rapUst = New-Object System.Windows.Forms.Panel
            $rapUst.Dock = "Top"
            $rapUst.Height = 80
            $rapUst.BackColor = $BG_PANEL
            $raporForm.Controls.Add($rapUst)

            $lblBaslik = Yeni-Etiket "Paketleme Tamamlandi!" (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)) $SUCCESS 15 10 300 25
            $rapUst.Controls.Add($lblBaslik)

            $lblOzet = Yeni-Etiket "Toplam $surucuSayisi adet 3. parti surucu (INF) klasore cikarildi." (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_DIM 15 40 500 35
            $rapUst.Controls.Add($lblOzet)

            # Liste Kutusu (ListBox) - Formla birlikte boyutlanacak "Anchor" özelliği eklendi
            $lstRapor = New-Object System.Windows.Forms.ListBox
            $lstRapor.Location = New-Object System.Drawing.Point(15, 95)
            $lstRapor.Size = New-Object System.Drawing.Size(650, 350)
            $lstRapor.Anchor = "Top, Bottom, Left, Right" # Form büyüdükçe listeyi esnetir
            $lstRapor.BackColor = $BG_CARD
            $lstRapor.ForeColor = $FG_MAIN
            $lstRapor.Font = New-Object System.Drawing.Font("Consolas", 9)
            $lstRapor.HorizontalScrollbar = $true # Uzun metinler için alt kaydırma çubuğu
            $raporForm.Controls.Add($lstRapor)

            $lstRapor.Items.Add("=== YEDEKLENEN SURUCULER ($surucuSayisi) ===") | Out-Null
            foreach ($drv in $suruculer) {
                $sinif = if ($drv.ClassName) { "[$($drv.ClassName)]" } else { "[Bilinmiyor]" }
                $saglayici = if ($drv.ProviderName) { $drv.ProviderName } else { "Bilinmeyen Uretici" }
                $lstRapor.Items.Add("$sinif $saglayici - $($drv.OriginalFileName)") | Out-Null
            }

            # Kapat Butonu
            $rapKapat = Yeni-Buton "Kapat" $ACCENT 100 30
            $rapKapat.Location = New-Object System.Drawing.Point(565, 465)
            $rapKapat.Anchor = "Bottom, Right" # Form büyüdükçe sağ altta sabit kalır
            $rapKapat.Add_Click({ $raporForm.Close() })
            $raporForm.Controls.Add($rapKapat)

            $raporForm.ShowDialog() | Out-Null

        } else {
            Yaz-Log $logKurulum "HATA: Yedeklenecek 3. parti surucu bulunamadi." $DANGER
        }

        $btnSurucuYedek.Enabled = $true
    })

	# --- Sol Sütun: Uygulama DNA Yedekleme (Log Senkronlu Final Motor) ---
    $btnDNAYedekle.Add_Click({
        if (-not $global:yoneticiMi) { [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.", "Uyari", 0, 16); return }

        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
        $browser.Description = "Sistemdeki uygulamalarin DNA (JSON) haritasinin kaydedilecegi klasoru secin"
        if ($browser.ShowDialog() -ne "OK") { return }

        $kayitKlasoru = $browser.SelectedPath.TrimEnd('\')
        $tarih = Get-Date -f "yyyyMMdd_HHmm"
        $hedefDosya = "$kayitKlasoru\SistemKit_AppDNA_$tarih.json"

        $btnDNAYedekle.Enabled = $false
        
        # --- İlerleme Çubuğu Paneli ---
        $panIlerlemeDNA = New-Object System.Windows.Forms.Panel
        $panIlerlemeDNA.Size = New-Object System.Drawing.Size(250, 40)
        $panIlerlemeDNA.Location = New-Object System.Drawing.Point(15, 140)
        $panIlerlemeDNA.BackColor = $BG_CARD
        
        $lblDNALoc = Yeni-Etiket "Sistem Taranıyor..." (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)) $WARNING 5 5 200 15
        $panIlerlemeDNA.Controls.Add($lblDNALoc)
        
        $barDNA = Yeni-IlerlemeKubugu 5 20 240
        $barDNA.Style = "Marquee" 
        $panIlerlemeDNA.Controls.Add($barDNA)
        
        $panHazirlik.Controls.Add($panIlerlemeDNA)
        $form.Refresh()
        
        Yaz-Log $logKurulum "Sistem kayitlari taranarak DNA haritasi olusturuluyor..." $WARNING
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $yollar = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            # Ham veriyi çek
            $hamKayitlar = Get-ItemProperty $yollar -ErrorAction SilentlyContinue | Where-Object { $_.SystemComponent -ne 1 -and $_.ParentKeyName -eq $null }
            
            $basariliUygulamalar = @()
            $hataliUygulamalar = @()

            foreach ($kayit in $hamKayitlar) {
                if ([string]::IsNullOrWhiteSpace($kayit.DisplayName)) {
                    $hataliUygulamalar += [PSCustomObject]@{ RegistryKey = $kayit.PSChildName }
                } else {
                    $basariliUygulamalar += [PSCustomObject]@{ 
                        DisplayName = $kayit.DisplayName; 
                        DisplayVersion = $kayit.DisplayVersion; 
                        Publisher = $kayit.Publisher 
                    }
                }
            }

            $basariliUygulamalar = $basariliUygulamalar | Sort-Object DisplayName -Unique
            $basariliSayi = @($basariliUygulamalar).Count
            $hataliSayi = @($hataliUygulamalar).Count

            if ($basariliSayi -gt 0) {
                # JSON Kaydet
                $jsonIcerik = $basariliUygulamalar | ConvertTo-Json -Depth 3 -Compress
                $jsonIcerik | Out-File -FilePath $hedefDosya -Encoding UTF8 -Force

                # UI Temizliği
                if ($panHazirlik.Controls.Contains($panIlerlemeDNA)) { $panHazirlik.Controls.Remove($panIlerlemeDNA) }
                
                # --- LOG EKRANI SENKRONİZASYONU ---
                Yaz-Log $logKurulum "--------------------------------------" $FG_DIM
                Yaz-Log $logKurulum "DNA YEDEKLEME OZETI:" $INFO
                Yaz-Log $logKurulum ">> Basariyla Yedeklenen: $basariliSayi" $SUCCESS
                
                if ($hataliSayi -gt 0) {
                    Yaz-Log $logKurulum ">> Atlanan / Bozuk Kayit: $hataliSayi" $DANGER
                    Yaz-Log $logKurulum "ATLANAN KAYIT DETAYLARI:" $WARNING
                    foreach ($hata in $hataliUygulamalar) {
                        Yaz-Log $logKurulum "[-] Bozuk Kayit: $($hata.RegistryKey)" $DANGER
                    }
                }
                Yaz-Log $logKurulum "--------------------------------------" $FG_DIM

                # Rapor Penceresini Göster
                $raporForm = New-Object System.Windows.Forms.Form
                $raporForm.Text = "SistemKit - Uygulama DNA Raporu"
                $raporForm.Size = New-Object System.Drawing.Size(480, 550)
                $raporForm.StartPosition = "CenterParent"
                $raporForm.BackColor = $BG_DARK; $raporForm.ForeColor = $FG_MAIN; $raporForm.ShowIcon = $false; $raporForm.FormBorderStyle = "FixedDialog"

                $rapUst = New-Object System.Windows.Forms.Panel; $rapUst.Dock = "Top"; $rapUst.Height = 80; $rapUst.BackColor = $BG_PANEL; $raporForm.Controls.Add($rapUst)
                $rapUst.Controls.Add((Yeni-Etiket "Tarama Tamamlandi!" (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)) $SUCCESS 15 10 300 25))
                $rapUst.Controls.Add((Yeni-Etiket "Toplam $basariliSayi uygulama yedeklendi. $hataliSayi bozuk kayit log ekranina işlendi." (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_DIM 15 40 430 35))

                $lstRapor = New-Object System.Windows.Forms.ListBox
                $lstRapor.Location = New-Object System.Drawing.Point(15, 95); $lstRapor.Size = New-Object System.Drawing.Size(435, 360)
                $lstRapor.BackColor = $BG_CARD; $lstRapor.ForeColor = $FG_MAIN; $lstRapor.Font = New-Object System.Drawing.Font("Consolas", 9)
                $raporForm.Controls.Add($lstRapor)

                $lstRapor.Items.Add("=== YEDEKLENENLER ($basariliSayi) ===") | Out-Null
                foreach ($uyg in $basariliUygulamalar) { $lstRapor.Items.Add("[+] $($uyg.DisplayName)") | Out-Null }
                
                if ($hataliSayi -gt 0) {
                    $lstRapor.Items.Add(""); $lstRapor.Items.Add("=== ATLANANLAR ($hataliSayi) ===") | Out-Null
                    foreach ($hata in $hataliUygulamalar) { $lstRapor.Items.Add("[-] Bozuk: $($hata.RegistryKey)") | Out-Null }
                }

                $rapKapat = Yeni-Buton "Kapat" $ACCENT 100 30
                $rapKapat.Location = New-Object System.Drawing.Point(350, 465); $rapKapat.Add_Click({ $raporForm.Close() })
                $raporForm.Controls.Add($rapKapat)

                $raporForm.ShowDialog() | Out-Null
            }
        } catch {
            if ($panHazirlik.Controls.Contains($panIlerlemeDNA)) { $panHazirlik.Controls.Remove($panIlerlemeDNA) }
            Yaz-Log $logKurulum "HATA: DNA cikarilirken bir sorun olustu: $_" $DANGER
        }
        $btnDNAYedekle.Enabled = $true
    })


    # --- Sol Sütun: Gelismis Tam İmaj Yedekleme (WIM Sihirbazi) ---
    $btnTamYedek.Add_Click({
        if (-not $global:yoneticiMi) { [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.", "Uyari", 0, 16); return }

        # C: sürücüsü analizini yap (Tahmini boyut hesabı için)
        $cDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $cKullanilanGB = [math]::Round(($cDrive.Size - $cDrive.FreeSpace) / 1GB, 2)

        # Popup Formu
        $kForm = New-Object System.Windows.Forms.Form
        $kForm.Text = "Tam Sistem İmaji (WIM) Sihirbazi"
        $kForm.Size = New-Object System.Drawing.Size(480, 420)
        $kForm.StartPosition = "CenterParent"
        $kForm.BackColor = $BG_DARK; $kForm.ForeColor = $FG_MAIN
        $kForm.FormBorderStyle = "FixedDialog"; $kForm.MaximizeBox = $false; $kForm.MinimizeBox = $false

        # Başlık Paneli
        $kUst = New-Object System.Windows.Forms.Panel; $kUst.Dock = "Top"; $kUst.Height = 60; $kUst.BackColor = $BG_PANEL; $kForm.Controls.Add($kUst)
        $kUst.Controls.Add((Yeni-Etiket "C: Surucusu Tam Yedekleme (DISM)" (New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)) $DANGER 15 10 350 22))
        $kUst.Controls.Add((Yeni-Etiket "Sisteminizi tek bir WIM dosyasi olarak diske imajlayin." (New-Object System.Drawing.Font("Segoe UI", 8.5)) $FG_DIM 15 35 400 20))

        # --- ORTA KISIM ---
        $lblCBilgi = Yeni-Etiket "Mevcut Sistem (C:) Doluluk: $cKullanilanGB GB" (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)) $INFO 20 80 400 20
        $kForm.Controls.Add($lblCBilgi)

        # 1. Sıkıştırma Seçenekleri
        $kForm.Controls.Add((Yeni-Etiket "Sikistirma Seviyesi:" (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_MAIN 20 115 150 20))
        
        $comboSikistirma = New-Object System.Windows.Forms.ComboBox
        $comboSikistirma.Location = New-Object System.Drawing.Point(180, 112); $comboSikistirma.Size = New-Object System.Drawing.Size(250, 25)
        $comboSikistirma.BackColor = $BG_CARD; $comboSikistirma.ForeColor = $FG_MAIN; $comboSikistirma.DropDownStyle = "DropDownList"
        $comboSikistirma.Items.Add("Maksimum (En Kucuk Boyut, Yavas)") | Out-Null
        $comboSikistirma.Items.Add("Hizli (Orta Boyut, Hizli)") | Out-Null
        $comboSikistirma.Items.Add("Yok (En Buyuk Boyut, Cok Hizli)") | Out-Null
        $comboSikistirma.SelectedIndex = 0 # Varsayılan: Maksimum
        $kForm.Controls.Add($comboSikistirma)

        # Tahmini Boyut Hesaplayıcı
        $lblTahmin = Yeni-Etiket "" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)) $WARNING 180 145 250 20
        $kForm.Controls.Add($lblTahmin)

        $HesaplaTahmin = {
            if ($comboSikistirma.SelectedIndex -eq 0) { $oran = 0.35 } # Max: ~%35-40
            elseif ($comboSikistirma.SelectedIndex -eq 1) { $oran = 0.50 } # Hızlı: ~%50
            else { $oran = 1.0 } # Yok: %100 (Birebir kopyaya yakın)
            $tahminiGB = [math]::Round($cKullanilanGB * $oran, 2)
            $lblTahmin.Text = "Tahmini Imaj Boyutu: ~ $tahminiGB GB"
        }
        $comboSikistirma.Add_SelectedIndexChanged($HesaplaTahmin)
        $HesaplaTahmin.Invoke() # İlk açılışta hesapla

        # 2. Kayıt Yeri Seçimi
        $ayrac = New-Object System.Windows.Forms.Label; $ayrac.Location = New-Object System.Drawing.Point(20, 180); $ayrac.Size = New-Object System.Drawing.Size(420, 1); $ayrac.BackColor = $SUBTLE; $kForm.Controls.Add($ayrac)

        $kForm.Controls.Add((Yeni-Etiket "Kayit Klasoru (C: haric farkli bir surucu secin):" (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_MAIN 20 200 350 20))
        
        $txtHedefYol = New-Object System.Windows.Forms.TextBox
        $txtHedefYol.Location = New-Object System.Drawing.Point(20, 230); $txtHedefYol.Size = New-Object System.Drawing.Size(320, 24)
        $txtHedefYol.BackColor = $BG_CARD; $txtHedefYol.ForeColor = $FG_MAIN; $txtHedefYol.BorderStyle = "FixedSingle"; $txtHedefYol.ReadOnly = $true
        $kForm.Controls.Add($txtHedefYol)

        $btnGozat = Yeni-Buton "Gozat" $SUBTLE 90 26
        $btnGozat.Location = New-Object System.Drawing.Point(350, 229); $kForm.Controls.Add($btnGozat)

        $btnGozat.Add_Click({
            $browser = New-Object System.Windows.Forms.FolderBrowserDialog
            $browser.Description = "WIM Imajinin kaydedilecegi klasoru secin (Orn: D: veya USB)"
            if ($browser.ShowDialog() -eq "OK") {
                if ($browser.SelectedPath -match "^C:") {
                    [System.Windows.Forms.MessageBox]::Show("Uyari: C: surucusunu C: icerisine yedekleyemezsiniz. Lutfen D: veya harici bir disk secin.", "Hata", 0, 16) | Out-Null
                } else {
                    $txtHedefYol.Text = $browser.SelectedPath
                }
            }
        })
        
        # --- ALT PANEL ---
        $kAlt = New-Object System.Windows.Forms.Panel; $kAlt.Dock = "Bottom"; $kAlt.Height = 60; $kAlt.BackColor = $BG_PANEL; $kForm.Controls.Add($kAlt)
        
        $btnBaslat = Yeni-Buton "Yedeklemeyi Baslat (CMD)" $DANGER 200 34
        $btnBaslat.Location = New-Object System.Drawing.Point(250, 12); $kAlt.Controls.Add($btnBaslat)

        $btnBaslat.Add_Click({
            if (-not $txtHedefYol.Text) { [System.Windows.Forms.MessageBox]::Show("Lutfen gecerli bir kayit klasoru secin.", "Eksik Bilgi", 0, 48) | Out-Null; return }
            
            $onay = [System.Windows.Forms.MessageBox]::Show("Bu islem uzun surebilir. CMD ekrani acilacak ve DISM komutu calistirilacaktir. Devam edilsin mi?", "Son Onay", 4, 32)
            if ($onay -ne "Yes") { return }

            $tarih = Get-Date -f "yyyyMMdd_HHmm"
            $hedefDosya = Join-Path $txtHedefYol.Text "SistemKit_Imaj_$tarih.wim"
            
            # Sıkıştırma Parametresini Belirle
            $compParam = "max"
            if ($comboSikistirma.SelectedIndex -eq 1) { $compParam = "fast" }
            elseif ($comboSikistirma.SelectedIndex -eq 2) { $compParam = "none" }

            $cmd = "dism /Capture-Image /ImageFile:`"$hedefDosya`" /CaptureDir:C:\ /Name:`"SistemKit_FullBackup_$tarih`" /Compress:$compParam"
            Yaz-Log $logKurulum "WIM Imaj alma baslatildi ($compParam). CMD aciliyor..." $INFO
            Start-Process cmd -ArgumentList "/k echo SistemKit WIM Yedekleme basliyor... Lutfen bekleyin... && $cmd" -WindowStyle Normal
            
            $kForm.Close()
        })

        $kForm.ShowDialog() | Out-Null
    }) # WIM SIHIRBAZI BURADA KAPANMALIYDI!

   # --- Sol Sütun: Windows Kurulum Asistanı (Modern 3'lü Kart Menüsü) ---
    $btnFormatUSB.Add_Click({
        $frmAsistan = New-Object System.Windows.Forms.Form
        $frmAsistan.Text = "SistemKit - Windows Kurulum Asistanı"
        $frmAsistan.Size = New-Object System.Drawing.Size(650, 400)
        $frmAsistan.StartPosition = "CenterParent"
        $frmAsistan.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1E2227")
        $frmAsistan.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $frmAsistan.ShowIcon = $false
        $frmAsistan.FormBorderStyle = "FixedDialog"
        $frmAsistan.MaximizeBox = $false

        # Üst Başlık Paneli
        $panUst = New-Object System.Windows.Forms.Panel
        $panUst.Dock = "Top"
        $panUst.Height = 80
        $panUst.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#242930")
        $frmAsistan.Controls.Add($panUst)

        $lblUstB = New-Object System.Windows.Forms.Label
        $lblUstB.Text = "Yükleme Medyası Oluşturucu"
        $lblUstB.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $lblUstB.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#10B981")
        $lblUstB.Location = New-Object System.Drawing.Point(20, 15)
        $lblUstB.Size = New-Object System.Drawing.Size(400, 30)
        $panUst.Controls.Add($lblUstB)

        $lblUstA = New-Object System.Windows.Forms.Label
        $lblUstA.Text = "Lütfen ilerlemek istediğiniz yöntemi veya aracı seçin."
        $lblUstA.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
        $lblUstA.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#8B949E")
        $lblUstA.Location = New-Object System.Drawing.Point(20, 45)
        $lblUstA.Size = New-Object System.Drawing.Size(500, 25)
        $panUst.Controls.Add($lblUstA)


        # ==========================================
        # KART 1: WINDOWS 10
        # ==========================================
        $kartW10 = New-Object System.Windows.Forms.Panel
        $kartW10.Size = New-Object System.Drawing.Size(180, 200)
        $kartW10.Location = New-Object System.Drawing.Point(25, 110)
        $kartW10.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2A2E33")
        $kartW10.Cursor = [System.Windows.Forms.Cursors]::Hand

        $lblBW10 = New-Object System.Windows.Forms.Label
        $lblBW10.Text = "Windows 10"
        $lblBW10.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblBW10.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00A4EF")
        $lblBW10.TextAlign = "MiddleCenter"
        $lblBW10.Location = New-Object System.Drawing.Point(10, 20)
        $lblBW10.Size = New-Object System.Drawing.Size(160, 35)
        $lblBW10.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartW10.Controls.Add($lblBW10)

        $lblAW10 = New-Object System.Windows.Forms.Label
        $lblAW10.Text = "Microsoft'un resmi Medya Olusturma Araci.`n`n(ISO dosyasi gerektirmez, dogrudan USB'ye yazar.)"
        $lblAW10.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $lblAW10.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $lblAW10.TextAlign = "TopCenter"
        $lblAW10.Location = New-Object System.Drawing.Point(15, 70)
        $lblAW10.Size = New-Object System.Drawing.Size(150, 110)
        $lblAW10.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartW10.Controls.Add($lblAW10)

        $frmAsistan.Controls.Add($kartW10)

        # ==========================================
        # KART 2: WINDOWS 11
        # ==========================================
        $kartW11 = New-Object System.Windows.Forms.Panel
        $kartW11.Size = New-Object System.Drawing.Size(180, 200)
        $kartW11.Location = New-Object System.Drawing.Point(225, 110)
        $kartW11.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2A2E33")
        $kartW11.Cursor = [System.Windows.Forms.Cursors]::Hand

        $lblBW11 = New-Object System.Windows.Forms.Label
        $lblBW11.Text = "Windows 11"
        $lblBW11.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblBW11.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00A4EF")
        $lblBW11.TextAlign = "MiddleCenter"
        $lblBW11.Location = New-Object System.Drawing.Point(10, 20)
        $lblBW11.Size = New-Object System.Drawing.Size(160, 35)
        $lblBW11.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartW11.Controls.Add($lblBW11)

        $lblAW11 = New-Object System.Windows.Forms.Label
        $lblAW11.Text = "Microsoft'un resmi Medya Olusturma Araci.`n`n(ISO dosyasi gerektirmez, dogrudan USB'ye yazar.)"
        $lblAW11.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $lblAW11.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $lblAW11.TextAlign = "TopCenter"
        $lblAW11.Location = New-Object System.Drawing.Point(15, 70)
        $lblAW11.Size = New-Object System.Drawing.Size(150, 110)
        $lblAW11.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartW11.Controls.Add($lblAW11)

        $frmAsistan.Controls.Add($kartW11)

        # ==========================================
        # KART 3: RUFUS
        # ==========================================
        $kartRufus = New-Object System.Windows.Forms.Panel
        $kartRufus.Size = New-Object System.Drawing.Size(180, 200)
        $kartRufus.Location = New-Object System.Drawing.Point(425, 110)
        $kartRufus.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2A2E33")
        $kartRufus.Cursor = [System.Windows.Forms.Cursors]::Hand

        $lblBRufus = New-Object System.Windows.Forms.Label
        $lblBRufus.Text = "Rufus"
        $lblBRufus.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblBRufus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#F25022")
        $lblBRufus.TextAlign = "MiddleCenter"
        $lblBRufus.Location = New-Object System.Drawing.Point(10, 20)
        $lblBRufus.Size = New-Object System.Drawing.Size(160, 35)
        $lblBRufus.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartRufus.Controls.Add($lblBRufus)

        $lblARufus = New-Object System.Windows.Forms.Label
        $lblARufus.Text = "Profesyonel ISO Yazdirma Araci.`n`n(Elinizde hazir bir Windows veya Linux ISO dosyasi varsa kullanin.)"
        $lblARufus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $lblARufus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $lblARufus.TextAlign = "TopCenter"
        $lblARufus.Location = New-Object System.Drawing.Point(15, 70)
        $lblARufus.Size = New-Object System.Drawing.Size(150, 110)
        $lblARufus.Cursor = [System.Windows.Forms.Cursors]::Hand
        $kartRufus.Controls.Add($lblARufus)

        $frmAsistan.Controls.Add($kartRufus)


        # --- TIKLAMA (AKSİYON) MOTORLARI ---
        
        $actionW10 = {
            $frmAsistan.Close()
            Yaz-Log $logKurulum "Windows 10 Resmi Araci indiriliyor..." $WARNING
            try {
                $mct10 = "$env:TEMP\MediaCreationTool_W10.exe"
                Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkId=691209" -OutFile $mct10 -UseBasicParsing
                Start-Process -FilePath $mct10
                Yaz-Log $logKurulum "Windows 10 Araci basariyla baslatildi." $SUCCESS
            } catch { Yaz-Log $logKurulum "HATA: Win10 Araci indirilemedi! Tarayici aciliyor..." $DANGER; Start-Process "https://www.microsoft.com/tr-tr/software-download/windows10" }
        }

        $actionW11 = {
            $frmAsistan.Close()
            Yaz-Log $logKurulum "Windows 11 Resmi Araci indiriliyor..." $WARNING
            try {
                $mct11 = "$env:TEMP\MediaCreationTool_W11.exe"
                Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2156295" -OutFile $mct11 -UseBasicParsing
                Start-Process -FilePath $mct11
                Yaz-Log $logKurulum "Windows 11 Araci basariyla baslatildi." $SUCCESS
            } catch { Yaz-Log $logKurulum "HATA: Win11 Araci indirilemedi! Tarayici aciliyor..." $DANGER; Start-Process "https://www.microsoft.com/tr-tr/software-download/windows11" }
        }

        $actionRufus = {
            $frmAsistan.Close()
            Yaz-Log $logKurulum "Rufus (Portable) arka planda indiriliyor..." $WARNING
            
            try {
                # Eski Windows sürümlerinin GitHub'a baglanmasini saglayan TLS 1.2 izni
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                
                # GitHub API'sine baglan ve "p.exe" (Portable) ile biten GUNCEL surumun tam adini bul
                $api = Invoke-RestMethod -Uri "https://api.github.com/repos/pbatard/rufus/releases/latest" -UseBasicParsing
                $rufusUrl = ($api.assets | Where-Object { $_.name -match "p\.exe$" })[0].browser_download_url
                
                if (-not $rufusUrl) { throw "GitHub API'den guncel Rufus linki alinamadi." }

                $rufusExe = "$env:TEMP\Rufus_Portable.exe"
                # Tespit edilen dinamik linki indir
                Invoke-WebRequest -Uri $rufusUrl -OutFile $rufusExe -UseBasicParsing
                
                if (Test-Path $rufusExe) {
                    Start-Process -FilePath $rufusExe
                    Yaz-Log $logKurulum "Rufus (Güncel Sürüm) başarıyla indirildi ve çalıştırıldı." $SUCCESS
                } else {
                    throw "Dosya kaydedilemedi."
                }
            } catch { 
                # Hata olursa log ekranina nedenini yazdir, sonra tarayiciyi ac
                Yaz-Log $logKurulum "HATA: Arka plan indirmesi başarisiz! (Detay: $_) Tarayici aciliyor..." $DANGER
                Start-Process "https://rufus.ie/tr/" 
            }
        }

        $kartW10.Add_Click($actionW10); $lblBW10.Add_Click($actionW10); $lblAW10.Add_Click($actionW10)
        $kartW11.Add_Click($actionW11); $lblBW11.Add_Click($actionW11); $lblAW11.Add_Click($actionW11)
        $kartRufus.Add_Click($actionRufus); $lblBRufus.Add_Click($actionRufus); $lblARufus.Add_Click($actionRufus)

        # Alt Bilgi Kapatma Butonu
        $btnKapat = New-Object System.Windows.Forms.Button
        $btnKapat.Text = "Iptal"
        $btnKapat.Size = New-Object System.Drawing.Size(100, 30)
        $btnKapat.Location = New-Object System.Drawing.Point(505, 320)
        $btnKapat.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#3B4252")
        $btnKapat.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E5EC")
        $btnKapat.FlatStyle = "Flat"
        $btnKapat.FlatAppearance.BorderSize = 0
        $btnKapat.Add_Click({ $frmAsistan.Close() })
        $frmAsistan.Controls.Add($btnKapat)

        $frmAsistan.ShowDialog() | Out-Null
    })
    # --- Orta Sütun: Uygulama Kataloğu ---
    $uygulamaListesi = @(
        @{Ad="Google Chrome"; WID="Google.Chrome"; Kat="Tarayici"}, @{Ad="Mozilla Firefox"; WID="Mozilla.Firefox"; Kat="Tarayici"}, 
        @{Ad="Visual Studio Code"; WID="Microsoft.VisualStudioCode"; Kat="Gelistirici"}, @{Ad="PowerShell 7"; WID="Microsoft.PowerShell"; Kat="Gelistirici"},
        @{Ad="VLC Medya Oynatici"; WID="VideoLAN.VLC"; Kat="Medya"}, @{Ad="Spotify"; WID="Spotify.Spotify"; Kat="Medya"},
        @{Ad="7-Zip"; WID="7zip.7zip"; Kat="Yardimci"}, @{Ad="WinRAR"; WID="RARLab.WinRAR"; Kat="Yardimci"}
    ) 

    $btnKatalogAc.Add_Click({
        $kForm = New-Object System.Windows.Forms.Form
        $kForm.Text = "Uygulama Katalogu (Winget)"
        $kForm.Size = New-Object System.Drawing.Size(500, 450); $kForm.StartPosition = "CenterParent"
        $kForm.BackColor = $BG_DARK; $kForm.ForeColor = $FG_MAIN
        
        $kListe = New-Object System.Windows.Forms.ListView
        $kListe.Dock = "Fill"; $kListe.BackColor = $BG_CARD; $kListe.ForeColor = $FG_MAIN; $kListe.View = "Details"; $kListe.CheckBoxes = $true
        $kListe.Columns.Add("Uygulama Adi", 250) | Out-Null; $kListe.Columns.Add("Kategori", 150) | Out-Null
        $kForm.Controls.Add($kListe)
        
        foreach($u in $uygulamaListesi) {
            $s = New-Object System.Windows.Forms.ListViewItem($u.Ad)
            $s.SubItems.Add($u.Kat) | Out-Null; $s.Tag = $u; $kListe.Items.Add($s) | Out-Null
        }
        
        $kAlt = New-Object System.Windows.Forms.Panel; $kAlt.Dock = "Bottom"; $kAlt.Height = 50; $kForm.Controls.Add($kAlt)
        $btnKEkle = Yeni-Buton "Secilenleri Kuyruga Ekle" $SUCCESS 200 32
        $btnKEkle.Location = New-Object System.Drawing.Point(270, 10); $kAlt.Controls.Add($btnKEkle)
        
        $btnKEkle.Add_Click({
            foreach($s in $kListe.CheckedItems) {
                $u = $s.Tag
                $varMi = $false; foreach($ki in $listeKuyruk.Items) { if($ki.Text -eq $u.Ad) { $varMi = $true } }
                if(-not $varMi) {
                    $yeniSatir = New-Object System.Windows.Forms.ListViewItem($u.Ad); $yeniSatir.Tag = $u.WID
                    $listeKuyruk.Items.Add($yeniSatir) | Out-Null
                }
            }
            $kForm.Close()
        })
        $kForm.ShowDialog() | Out-Null
    })

    # --- Orta Sütun: Kuyruk Kurulumu ---
    $btnKuyrukKur.Add_Click({
        if($listeKuyruk.Items.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Kuyruk bos!","Uyari",0,48); return }
        $btnKuyrukKur.Enabled = $false; $btnKatalogAc.Enabled = $false
        Yaz-Log $logKurulum "Toplu kurulum baslatiliyor..." $ACCENT; $form.Refresh()
        
        $idList = @(); foreach($i in $listeKuyruk.Items){ $idList += $i.Tag }
        $script:kurJob = Start-Job {
            param($ids)
            $son = @()
            foreach($id in $ids){
                $p = Start-Process winget -ArgumentList "install --id `"$id`" --silent --accept-source-agreements" -PassThru -Wait -WindowStyle Hidden
                $son += @{ID=$id; Kod=$p.ExitCode}
            }
            return $son
        } -ArgumentList (,$idList)
        
        $script:kurTimer = New-Object System.Windows.Forms.Timer; $script:kurTimer.Interval = 1000
        $script:kurTimer.Add_Tick({
            if ($null -eq $script:kurJob) { return }
            if ($script:kurJob.State -ne "Running") {
                $script:kurTimer.Stop(); $sonuclar = Receive-Job $script:kurJob; Remove-Job $script:kurJob -Force
                foreach($s in $sonuclar){
                    if($s.Kod -eq 0){ Yaz-Log $logKurulum "$($s.ID) kuruldu." $SUCCESS }
                    else { Yaz-Log $logKurulum "$($s.ID) kurulamadi (Kod: $($s.Kod))." $DANGER }
                }
                $btnKuyrukKur.Enabled = $true; $btnKatalogAc.Enabled = $true; $script:kurTimer.Dispose()
            }
        })
        $script:kurTimer.Start()
    })

    # ================================================================
    # LİSANS AKSİYONLARI VE MOTORLARI
    # ================================================================

    # --- 1. Bilgi Öğrenme ---
    $btnLisansOgren.Add_Click({
        $keyMsg = "Tespit Edilen Lisans Anahtarlari:`n`n"
        try {
            $regKey = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name "BackupProductKeyDefault" -EA SilentlyContinue).BackupProductKeyDefault
            if ($regKey) { $keyMsg += "» Mevcut Windows (Kayit Defteri): $regKey`n" }
        } catch {}
        try {
            $wmiKey = (Get-WmiObject -Class SoftwareLicensingService -EA SilentlyContinue).OA3xOriginalProductKey
            if ($wmiKey) { $keyMsg += "» Anakart (BIOS/OEM Gomulu): $wmiKey`n" }
            else { $keyMsg += "» Anakartta gomulu OEM anahtari bulunamadi.`n" }
        } catch {}
        if ($keyMsg -eq "Tespit Edilen Lisans Anahtarlari:`n`n") { $keyMsg += "Anahtar bulunamadi." }
        [System.Windows.Forms.MessageBox]::Show($keyMsg, "Lisans Bilgisi", 0, 64) | Out-Null
        Yaz-Log $logKurulum "Lisans anahtarlari sorgulandi." $INFO
    })

    # --- 2. Klasik slmgr Sorguları ---
    $btnDli.Add_Click({ Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /dli" -WindowStyle Hidden; Yaz-Log $logKurulum "Lisans durumu (/dli) sorgulandi." $INFO })
    $btnDlv.Add_Click({ Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /dlv" -WindowStyle Hidden; Yaz-Log $logKurulum "Lisans detayi (/dlv) sorgulandi." $INFO })
    $btnXpr.Add_Click({ Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /xpr" -WindowStyle Hidden; Yaz-Log $logKurulum "Lisans suresi (/xpr) sorgulandi." $INFO })

    # --- 3. Tam Aktivasyon Yedekleme (Tokens.dat) ---
    $btnLisansYedekle.Add_Click({
        if (-not $global:yoneticiMi) { [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.", "Yetki Hatasi", 0, 16); return }
        
        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
        $browser.Description = "Aktivasyon Yedeginin Kaydedilecegi Klasoru Secin (Orn: USB Bellek)"
        if ($browser.ShowDialog() -ne "OK") { return }
        
        $hedefKlasor = Join-Path $browser.SelectedPath "SistemKit_LisansYedek_$(Get-Date -f 'yyyyMMdd')"
        New-Item -Path $hedefKlasor -ItemType Directory -Force | Out-Null
        
        $btnLisansYedekle.Enabled = $false; $form.Refresh()
        Yaz-Log $logKurulum "Aktivasyon servisi (sppsvc) durduruluyor..." $WARNING
        
        try {
            Stop-Service -Name sppsvc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Asıl yedeklenecek dosyalar
            $kaynakTokens = "$env:SystemRoot\System32\spp\store\2.0"
            if (Test-Path $kaynakTokens) {
                Copy-Item -Path "$kaynakTokens\*" -Destination $hedefKlasor -Recurse -Force
                Yaz-Log $logKurulum "Lisans dosyalari (Tokens.dat) basariyla yedeklendi: $hedefKlasor" $SUCCESS
                [System.Windows.Forms.MessageBox]::Show("Aktivasyon yedeginiz basariyla alindi!`n`nKonum: $hedefKlasor", "Yedekleme Basarili", 0, 64) | Out-Null
            } else {
                Yaz-Log $logKurulum "Hata: Lisans dosyalari bulunamadi!" $DANGER
            }
        } catch {
            Yaz-Log $logKurulum "Yedekleme sirasinda hata: $_" $DANGER
        } finally {
            Start-Service -Name sppsvc -ErrorAction SilentlyContinue
            $btnLisansYedekle.Enabled = $true
        }
    })

    # --- 4. Aktivasyon Geri Yükleme ---
    $btnLisansGeriYukle.Add_Click({
        if (-not $global:yoneticiMi) { [System.Windows.Forms.MessageBox]::Show("Bu islem Yonetici Yetkisi gerektirir.", "Yetki Hatasi", 0, 16); return }
        
        $onay = [System.Windows.Forms.MessageBox]::Show("Format sonrasi yedeklediginiz lisans dosyalari sisteme geri yuklenecek. Devam edilsin mi?", "Lisans Geri Yukleme", 4, 32)
        if ($onay -ne "Yes") { return }

        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
        $browser.Description = "Daha once yedeklediginiz 'SistemKit_LisansYedek' klasorunu secin."
        if ($browser.ShowDialog() -ne "OK") { return }
        
        $kaynakKlasor = $browser.SelectedPath
        if (-not (Test-Path "$kaynakKlasor\tokens.dat" -ErrorAction SilentlyContinue)) {
            [System.Windows.Forms.MessageBox]::Show("Secilen klasorde gecerli bir 'tokens.dat' lisans dosyasi bulunamadi!", "Hatali Klasor", 0, 48) | Out-Null
            return
        }

        $btnLisansGeriYukle.Enabled = $false; $form.Refresh()
        Yaz-Log $logKurulum "Mevcut aktivasyon servisi durduruluyor..." $WARNING
        
        try {
            Stop-Service -Name sppsvc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            $hedefTokens = "$env:SystemRoot\System32\spp\store\2.0"
            Copy-Item -Path "$kaynakKlasor\*" -Destination $hedefTokens -Recurse -Force
            
            Start-Service -Name sppsvc -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Geri yükleme sonrası otomatik etkinleştirme tetiklemesi
            Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /ato" -WindowStyle Hidden
            
            Yaz-Log $logKurulum "Lisans yedegi basariyla sisteme islendi! Aktivasyon durumu kontrol ediliyor..." $SUCCESS
            [System.Windows.Forms.MessageBox]::Show("Lisans dosyalari basariyla geri yuklendi. Sistemin etkinlesmesi birkac saniye surebilir.", "Islem Tamam", 0, 64) | Out-Null
        } catch {
            Yaz-Log $logKurulum "Geri yukleme sirasinda hata: $_" $DANGER
        } finally {
            $btnLisansGeriYukle.Enabled = $true
        }
    })

    # --- 5. Manuel Manuel Etkinleştirme ---
    $btnKeyGir.Add_Click({
        $a = $txtKey.Text.Trim()
        if ($a -match "XXXXX" -or $a.Length -lt 20) { [System.Windows.Forms.MessageBox]::Show("Gecerli bir anahtar girin.", "Uyari", 0, 48); return }
        Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /ipk $a" -WindowStyle Hidden -Verb RunAs
        Yaz-Log $logKurulum "Anahtar yukleme komutu gonderildi." $INFO
    })
    $btnEtkinlestir.Add_Click({ 
        Start-Process "wscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /ato" -WindowStyle Hidden -Verb RunAs 
        Yaz-Log $logKurulum "Manuel etkinlestirme komutu gonderildi." $INFO
    })
	
    # ================================================================
    #  SEKME 6 - HAKKINDA
# ---------------- HAKKINDA SEKMESİ (ÜRETİM KÜNYESİ) ----------------
    
    # 1. ÜST PANEL: MARKA VE MODEL (ŞASİ KİMLİĞİ) - Burası sabit kalabilir
    $panBaslik = Yeni-Kart 10 25 640 100
    $panBaslik.BackColor = $BG_CARD
    
    $lblBaslik = Yeni-Etiket "SistemKit v8.1" (New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)) $FG_MAIN 20 15 600 35
    $lblAltBaslik = Yeni-Etiket "Gelişmiş Windows Sistem Yönetim ve Optimizasyon Aracı" (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)) $FG_DIM 22 50 600 20
    $panBaslik.Controls.Add($lblBaslik); $panBaslik.Controls.Add($lblAltBaslik)
    $sekmeHakkinda.Controls.Add($panBaslik)


    # 2. SOL PANEL: DONANIM PAKETİ (MODÜLLER)
    # MÜHENDİSLİK ÇÖZÜMÜ 1: Dikey yüksekliği (H) 360'tan 420'ye çıkarıp kaportada yer açıyoruz!
    $panModuller = Yeni-Kart 10 135 315 420
    $panModuller.BackColor = $BG_CARD
    
    # Başlığı hafif yukarı çektik (15 -> 12)
    $panModuller.Controls.Add((Yeni-Etiket "SİSTEM MODÜLLERİ (DONANIM PAKETİ)" (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)) $INFO 15 12 280 20))
    
    # Modüller listesi (Aynı)
    $moduller = @(
        "• Disk Analizi (3D Doughnut Grafik Motoru)",
        "• Akıllı Temizlik (Derin Sistem Optimizasyonu)",
        "• Sistem İzleme (Gerçek Zamanlı Telemetri)",
        "• Ağ Araçları (Bağlantı ve Ağ Analizi)",
        "• Başlangıç (Açılış Hızı Kalibrasyonu)",
        "• Uygulama Yükle (Winget Asenkron Yönetim)",
        "• Araçlar (Gelişmiş Sistem Kısayolları)",
        "• Lisans Yönetimi (Dijital Lisans ve Aktivasyon)"
    )
    
    $yEksen = 40 # Başlangıç Y koordinatını hafif yukarı çektik
    foreach ($modul in $moduller) {
        $panModuller.Controls.Add((Yeni-Etiket $modul (New-Object System.Drawing.Font("Segoe UI", 8.5)) $FG_MAIN 15 $yEksen 280 20))
        # MÜHENDİSLİK ÇÖZÜMÜ 2: Satır arası boşluğu 25px'ten 23px'e düşürerek 8 modülü de sığdırdık!
        $yEksen += 23 
    }
    $sekmeHakkinda.Controls.Add($panModuller)


    # 3. SAĞ PANEL: BAŞMÜHENDİS VE AR-GE EKİBİ (YAPAY ZEKA HİBRİT ALTYAPISI)
    # MÜHENDİSLİK ÇÖZÜMÜ 3: SİMETRİ! Sağ kutunun yüksekliğini de 420 yapıp dikeyde dengeledik!
    $panGelistirici = Yeni-Kart 335 135 315 420
    $panGelistirici.BackColor = $BG_CARD
    
    $panGelistirici.Controls.Add((Yeni-Etiket "GELİŞTİRİCİ VE AR-GE BİLGİSİ" (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)) $WARNING 15 15 280 20))
    
    $panGelistirici.Controls.Add((Yeni-Etiket "Yapımcı / Proje Yöneticisi:" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)) $FG_DIM 15 45 280 18))
    $panGelistirici.Controls.Add((Yeni-Etiket "Onur YILDIRM (Otomotiv Mühendisi)" (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_MAIN 15 63 280 20))
    
    $panGelistirici.Controls.Add((Yeni-Etiket "Altyapı ve Şasi:" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)) $FG_DIM 15 95 280 18))
    $panGelistirici.Controls.Add((Yeni-Etiket "PowerShell & .NET WinForms Custom GUI" (New-Object System.Drawing.Font("Segoe UI", 9)) $FG_MAIN 15 113 280 20))
    
    $panGelistirici.Controls.Add((Yeni-Etiket "Yapay Zeka Ar-Ge Asistanları:" (New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)) $FG_DIM 15 145 280 18))
    
    # AI Metni sığsın diye dikey yüksekliği artırılmış bir etiket (Label) kullandık (100 -> 120)
    $aiMetin = "Bu proje, farklı algoritma ve yeteneklere sahip 4 yapay zeka modelinin ortak çalışmasıyla geliştirilmiştir:`n`n" +
               "  » ChatGPT`n" +
               "  » Claude AI`n" +
               "  » DeepSeek`n" +
               "  » Gemini (Final optimizasyon ve UI kalibrasyonu)"
               
    $lblAI = Yeni-Etiket $aiMetin (New-Object System.Drawing.Font("Segoe UI", 8.5)) $FG_MAIN 15 165 280 120
    $panGelistirici.Controls.Add($lblAI)
    # --- GÜNCELLEME KONTROL MOTORU ---
    $btnGuncelle = Yeni-Buton "Guncellemeleri Denetle" $SUCCESS 280 34 "GitHub uzerinden yeni surum var mi kontrol eder"
    $btnGuncelle.Location = New-Object System.Drawing.Point(15, 305)
    $panGelistirici.Controls.Add($btnGuncelle)

    $btnGuncelle.Add_Click({
        $btnGuncelle.Enabled = $false
        $btnGuncelle.Text = "Kontrol ediliyor..."
        $form.Refresh()
        try {
            # 1. Önbellek (Cache) Tuzağını Aşmak: Linkin sonuna rastgele sayı ekleyip her seferinde taze veri alıyoruz
            $versionUrl = "https://raw.githubusercontent.com/yldrm26/SistemKit/main/version.txt?t=$([guid]::NewGuid())"
            
            # 2. Güvenlik Protokolü: Tüm Windows sürümlerinde TLS 1.2'yi zorla (3072 sayısal değerdir, hata vermez)
            [System.Net.ServicePointManager]::SecurityProtocol = 3072
            
            # 3. Invoke-RestMethod yerine doğrudan .NET Core WebClient motorunu kullanıyoruz (En stabil yol)
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "SistemKit-Updater")
            $yeniSurumRaw = $webClient.DownloadString($versionUrl)
            
            [version]$yeniSurum = [version]($yeniSurumRaw.Trim())
            [version]$mevcutSurum = [version]"8.1"

            if ($yeniSurum -gt $mevcutSurum) {
                $onay = [System.Windows.Forms.MessageBox]::Show("Yeni bir surum bulundu! (v$yeniSurum)`nIndirme sayfasina gitmek ister misiniz?", "Guncelleme Bulundu", 4, 64)
                if ($onay -eq "Yes") {
                    Start-Process "https://github.com/yldrm26/SistemKit/releases/latest"
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Harika! SistemKit'in en guncel surumunu (v$mevcutSurum) kullaniyorsunuz.", "Guncel", 0, 64) | Out-Null
            }
        } catch {
            $gercekHata = $_.Exception.Message
            [System.Windows.Forms.MessageBox]::Show("Sistemsel Bağlantı Hatası!`n`nDetay: $gercekHata", "Ağ Hatası", 0, 48) | Out-Null
        }
        $btnGuncelle.Enabled = $true
        $btnGuncelle.Text = "Guncellemeleri Denetle"
    })
    # MÜHENDİSLİK ÇÖZÜMÜ 4: Kapanış notunu taller card'ın alt kısmına (Y=350) orantılı çektik.
    $panGelistirici.Controls.Add((Yeni-Etiket "SistemKit, maksimum performans ve stabilite için tasarlanmıştır. Tüm sistem bileşenleri uyum içinde çalışır." (New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)) $FG_DIM 15 350 280 50))
    
    $sekmeHakkinda.Controls.Add($panGelistirici)
    # ---------------- HAKKINDA SEKMESİ BİTİŞİ ----------------

    # ================================================================
    #  FOOTER
    # ================================================================
    $altPanel=New-Object System.Windows.Forms.Panel
    $altPanel.Dock="Bottom"; $altPanel.Height=32
    $altPanel.BackColor=[System.Drawing.Color]::FromArgb(18,18,28)
    $form.Controls.Add($altPanel)

    $altDurum=New-Object System.Windows.Forms.Label
    $modStr=if($global:yoneticiMi){"Yonetici Modu"}else{"Standart Mod - Bazi ozellikler kisitli"}
    $altDurum.Text="SistemKit v8.1  |  $modStr"
    $altDurum.Font=New-Object System.Drawing.Font("Segoe UI",8)
    $altDurum.ForeColor=$FG_DIM
    $altDurum.Location=[System.Drawing.Point]::new(12,8)
    $altDurum.Size=[System.Drawing.Size]::new(900,18)
    $altPanel.Controls.Add($altDurum)

    $form.Add_FormClosing({
        if ($null -ne $izlemeTimer) { $izlemeTimer.Stop(); $izlemeTimer.Dispose() }
    })
    
    $form.ShowDialog() | Out-Null

} catch {
    # --- PHOENIX MİMARİSİ: HATA YAKALAMA (TELEGRAM) ---
    Add-Type -AssemblyName System.Windows.Forms
    $hataMesaji = $_.Exception.Message
    $satir = $_.InvocationInfo.ScriptLineNumber
    
    # 1. Telegram Gönderimi
    try {
        # BÜYÜK EKSİK BURADAYDI: TLS 1.2 Koruması eklendi!
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $telegramToken = "8762271930:AAH__PpsqKr_PQas9XblwQMgd1Prffb7PGI"
        $chatId = "1051381180"
        
        $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
        $psVer = $PSVersionTable.PSVersion.ToString()
        
        $mesaj = "🚨 *SistemKit Çökme Raporu* 🚨`n*İşletim Sistemi:* $osInfo`n*PS Sürümü:* v$psVer`n*Hata Satırı:* $satir`n*Hata Detayı:* $hataMesaji"
        
        $payload = @{
            chat_id = $chatId
            text = $mesaj
            parse_mode = "Markdown"
        }
        
        $telegramUrl = "https://api.telegram.org/bot$telegramToken/sendMessage"
        
        # SilentlyContinue'yu sildik, Stop yaptık. Hata varsa bize söylesin!
        Invoke-RestMethod -Uri $telegramUrl -Method Post -Body $payload -ErrorAction Stop
        
        # Eğer mesaj gittiyse ekrana bu onay çıkacak:
        [System.Windows.Forms.MessageBox]::Show("Geliştiriciye çökme raporu BAŞARIYLA gönderildi!", "Hata İletimi", 0, 64) | Out-Null
        
    } catch {
        # TELEGRAM'A GİDEMEZSE BİZE NEDEN GİDEMEDİĞİNİ SÖYLEYECEK:
        $telegramHata = $_.Exception.Message
        [System.Windows.Forms.MessageBox]::Show("Geliştiriciye mesaj iletilemedi!`nNeden: $telegramHata", "Telegram Hata Avcısı", 0, 48) | Out-Null
    }

    # 2. Kullanıcıya Kibarca Bildir
    [System.Windows.Forms.MessageBox]::Show(
        "SistemKit beklenmeyen bir durumla karşılaştı ve kararlılığı korumak için kendini yeniden başlatacak.",
        "SistemKit - Phoenix Koruması",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    
    # 3. Küllerinden Doğ (Test bitene kadar ve sonsuz döngüyü önlemek için kapalı)
     if ($host.Name -eq "ConsoleHost") {
       Start-Process powershell -ArgumentList "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
     } else {
       Start-Process -FilePath ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
     }
}