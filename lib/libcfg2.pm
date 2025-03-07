#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb
#--------------------------------------------------------------------------
# "@(#) $Id: libcfg2.pm,v 1.70 2022/11/14 13:15:24 beg Exp $"
#--------------------------------------------------------------------------
#-----------------------------------------------------------------------
# Copyright (c) 1999-2008 by SEAL Systems
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Zeilen mit #split bitte nicht entfernen!
#-----------------------------------------------------------------------
{
package libcfg2;

use strict;
use integer;
use Memoize;
use Cwd 'abs_path';
use vars qw($Utf8Available $VERSION $rLang $CacheAvailable);
use Encode::Guess;
$VERSION = sprintf("%d.%02d", q$Revision: 1.70 $ =~ /(\d+)\.(\d+)/);
$CacheAvailable = 0;

sub useCachedFiles
    {
    memoize('_ReadCfg');
    $CacheAvailable = 1;
    }
#--------------------------------------------------------------------

# delay loading msghandler until we need the first string
sub Get
    {
    unless (defined $rLang)
        {
        eval 'use seppperl::msghandler;';
        $rLang = "seppperl::msghandler"->New(undef, "os", "lib");
        }
    return $rLang->Get(@_);
    }


use Carp;

 # use section;
 # unnoetig und falsch, weil in derselben Datei

 #
 # Package-globale Variablen.
 #
use vars qw (
@ISA
$ID
@ID
);
# Die folgenden Variablen koennen notfalls von aussen angesprochen und
# modifiziert werden ($libcfg2::CommentSign).
# nach dem require - vor dem ReadCfg !!!
# siehe jedoch SetModes !!!
use vars qw (
$ValidSectionNameSigns
$ValidKeyNameSigns
$CommentSign
$Utf8ValidSectionNameSigns
$Utf8ValidKeyNameSigns
$DBG
);

 #              ä   ö   ü   Ä   Ö   Ü   ß
my $Umlaute = "\xe4\xf6\xfc\xc4\xd6\xdc\xdf";
my $DanishSigns = "\xe5\xe6\xf8\xc5\xc6\xd8";
$ValidSectionNameSigns = "\x00-\xff",
$ValidKeyNameSigns     = '\\\\a-zA-Z0-9_:%\\/\\-\\.\\+' . $Umlaute . $DanishSigns,
$CommentSign           = "#",
$Utf8ValidSectionNameSigns = "^\\]",  # allow all but closing brace
$Utf8ValidKeyNameSigns     = "^=\\s", # allow all but = (separator) and white spaces


 #
 # Datei-globale Variablen mit my hier einfuegen
 #
my $DefaultSectionName = "_NONE";
my $WrongKeyName = "_NONE";
my $DefaultFormat    = "  %-20s %s %s\n";

my %DefaultModes = (
     GETMODE => "ENV",
     SETMODE => "NOQU",
     SEPARATOR => "=",
     FORMAT    => $DefaultFormat,
     KEYRE => "",
     VALUERE => "",
     SECTIONSIGNS  => "",
     COMMENTSIGN  => "",
     RETURNQUOTES => "NO",
     FOLDKEYCASE => "NO",
     SORT => "NO",
     AUTOUTF8 => "NO",
     UTF8 => "NO",
     NOBLANKLINES => "NO",
);
# -------------------------------------------------------------
# Debug-Ausgabe, wenn
# setenv DEB_CFG 1
# oder
# setenv DEBUG 1

$DBG = $ENV{DEB_CFG} ? sub { print @_ } : sub {};
# -------------------------------------------------------------
# Diese Version stellt eine komplette Ueberarbeitung dar. Wegen
# Beseitigung einiger Bugs bzw. wunschgemaess gibt es folgende
# Inkompatibilitaeten zu den Vorgaengerversionen.
#
# - Zeilen, die nicht angefasst wurden, werden einschliesslich fuehrender
#   Kommentarzeilen genauso geschrieben wie sie gelesen wurden. Auch
#   Fortsetzungszeilen bleiben dabei erhalten.
#   Kommentare werden immer beim naechsten erkannten Konstrukt abgespeichert,
#   also Kommentare vor dem [Section]-Eintrag bei diesem, solche danach
#   beim ersten Schluesselwort. Wenn es gebraucht wird koennte man das
#   aber noch steuern (ich denke da an #> oder #< zur Steuerung).
# - Kommentare am Ende einer Zeile wurden bisher mit GetValue zurueckgegeben.
#   Das ist jetzt nicht mehr so.
# - "" wurden bisher mit GetValue zurueckgegeben. Das ist jetzt nicht mehr so.
#   Beim Schreiben koennen auf Wunsch "" erzeugt werden.
#   # innerhalb von "" definiert keinen Kommentar.
# - Den Parameter @Comment bei SetValue und AddValue gibt es nicht mehr.
#   Auf Wunsch koennen aber beliebige Zeilen einschliesslich Kommentarzeilen
#   uebergeben werden.
# - Die Funktion GetComment ist (noch) nicht implementiert. Wer sie braucht,
#   bitte melden in welchem Zusammenhang.
# - Die internen Datenstrukturen haben sich geaendert. Darum:
#   Lasst von den Daten die Pfoten,
#   verwendet die Methoden!
#
# Die vorkommenden CFG-Dateien haben anscheinend aus historischen Gruenden
# keine ganz einheitliche Syntax und werden von verschiedenen Libraries
# gelesen. Der Author hat versucht nach bestem Wissen und Gewissen eine
# Perl-Schnittstelle zu schaffen. Bitte beim Testen die zurueckgegebenen
# Werte bzw. die neu erzeugten CFG-Dateien sorgfaeltig pruefen, ob diese
# im jeweiligen Zusammenhang Ok sind.
# -------------------------------------------------------------
# Gemeinsame Konventionen fuer package libcfg2
#
# Wenn nicht anders erwaehnt, wird bei Fehler undef oder ()
# zurueckgegeben. Eine Fehlerbeschreibung wird in $::ErrMsg
# hinterlegt.
# -------------------------------------------------------------
# Die folgenden Funktionen werden zum Lesen von Cfg-Dateien benoetigt.
# -------------------------------------------------------------
# $rCfg = libcfg2->New ($Separator);
#
# Es wird ein leeres Config-Datei-Objekt zurueckgegeben.
# -------------------------------------------------------------
# Parameter:
#
# $Separator     In    Trennzeichen (Default: "=").
#
# Return:        Leeres Config-Datei-Objekt.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub New
{
my ($Class, $Sep) = @_;

my $this = [
    { %DefaultModes }, #  
    [],                # Section Namen
    {},                # Section Referenzen
    "",                # Trailer (Kommentare nach letztem Eintrag)
];

bless ($this, $Class);
$this->SetModes (SEPARATOR => $Sep) if ($Sep);  # Separator
$this->SetModes (BomAtStart => undef);
return ($this);
}

sub Utf8Available
    {
    return $Utf8Available if (defined $Utf8Available);
    $Utf8Available = 0;
    eval 'use Encode;';
    if (! $@)
        {
        $Utf8Available = 1;
        }
    return $Utf8Available;
    }

# -------------------------------------------------------------
# $Ok = $rCfg->SetModes(MODE => $Value, ...);
#
# Modale Einstellungen fuer dieses CFG-Objekt werden gesetzt.
# Zur Zeit ist folgendes moeglich:
#
# GETMODE   Der Ersetzungs-Modus fuer die Function GetValue
#           (ENV, NO, ASIS).
# SETMODE   Der Art-Modus fuer die Function SetValue
#           (NOQU, QUOT, ASIS).
# SEPARATOR Trennzeichen. Dieses wird an folgenden Stellen benutzt:
#           Beim Einlesen: in R.E., wenn KEYRE leer ist
#           Bei GetValue:  in R.E, wenn KEYRE leer ist.
#           Bei SetValue:  als String.
# FORMAT    Ausgabeformat fuer SetValue. So werden die 3 Variablen
#           Schluesselwort, Trennzeichen, Wert ausgegeben.
#           Default: "  %-20s %s %s\n" - \n nicht vergessen!
# Die naechsten vier modalen Werte sind defaultmaessig leer. Es werden
# dann die alten globalen Variablen benutzt. Man kann aber mit diesen
# Werten die Syntaxpruefung objektbezogen definieren.
# COMMENTSIGN  Dieses Zeichen leitet einen Kommentar ein.
# SECTIONSIGNS String mit allen Zeichen, die in Sectionnamen gueltig sind.
# KEYRE        Mit dieser R.E. wird beim Einlesen nach Schluesselworten
#              gesucht. Wenn ein Match erfolgt, wird der in Klammern stehende
#              Teil zum Schluesselwort. Es wird aber die komplette Zeile
#              einschliesslich fuehrender Kommentarzeilen und folgender
#              Fortsetzungszeilen gespeichert.
# VALUERE      Mit dieser R.E. wird bei GetValue ein Wert ermittelt. Sie wird
#              auf die erste gespeicherte Nichtkommentarzeile (ohne \ und \n)
#              angewendet, dient also effektiv zum Ausblenden des
#              Schluesselworts.
#              Wenn ein Match erfolgt, wird der in Klammern stehende
#              Teil zum Werte, der allerdings noch um Fortsetzungszeilen
#              erweitert wird.
# RETURNQUOTES YES " und \ innerhalb von "" werden zurueckgegeben
#                  (alter Modus).
#              NO  " werden nicht zurueckgegeben und \ innerhalb von "" wird
#                  als Escape betrachtet (Default, wird aber auf YES gesetzt,
#                  wenn mit new initialisiert wird).
# 
# SORT         YES Die Keys innerhalb einer Section werden sortiert ausgegeben.
#              NO  Keys werden wie im Hash gespeichert ausgegeben (Default).
# AUTOUTF8     YES Beim Einlesen wird die UTF-8 BOM ausgewertet und dann
#                  die Datei mit Perl-Unicodestrings eingelesen. Setzt dann UTF8 Flag.
#              NO  Die UTF-8 BOM wird einfach ignoriert (für PLOSSYS) (Default).
# UTF8         YES Die Konfig soll als UTF-8 kodierte Datei gespeichert werden
#                  mit einer UTF-8 BOM vorne dran, damit ein AUTOUTF8 die auch
#                  wieder als solche einlesen kann (und Notepad, GVIM, ...)
#              NO  Die Konfig wird normal kodiert (latin1) gespeichert (Default).
#
# Mit SetModes kann das Verhalten beeinflusst werden, ohne dass
# die einzelnen Aufrufe geaendert werden muessen.
# -------------------------------------------------------------
# Parameter:
#
# Wertepaare, die im Objekt gespeichert werden.
#
# Return:        $rCfg .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub SetModes
    {
    my $this = shift (@_);

    my $rhModes = $this->[0];
    my $Key;

    while ($Key = shift (@_))
        {
        $rhModes->{$Key} = shift (@_);
        }
    return $this;
    } # SetModes
# -------------------------------------------------------------
# $ModeVal = $rCfg->GetMode ($ModeKey, $bUc);
#
# Abfrage von modalen Einstellungen fuer ein CFG-Objekt.
# -------------------------------------------------------------
# Parameter:
#
# $ModeKey       In    Schluesselwort
# $bUc           In    Wenn wahr, wird der Wert in Grossbuchstaben umgewandelt.
#
# Return:        Zugehoeriger Wert.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetMode
    {
    my ($this, $ModeKey, $bUc) = @_;

    my $rhModes = $this->[0];

    my $Mode = $rhModes->{$ModeKey};
    $Mode = uc ($Mode) if ($bUc);
    return $Mode;
    } # GetMode
# -------------------------------------------------------------
READCFG: {
 # gemeinsame lokale Variablen fuer ReadCfg und Hilfsroutine _bufferout

my $Buffer;
my $Name;
my $Type;
my $Config;
my $RefSection;
my $bFold;

sub _bufferout
{
if ($Type == 2)    # Key
    {
    $RefSection ||= $Config->AddSection($DefaultSectionName, "");
    $Name = lc($Name) if $bFold;
    $RefSection->AddKey($Name, $Buffer);
    }
elsif ($Type == 1)    # Section
    {
    $RefSection = $Config->AddSection($Name, $Buffer);
    }
elsif ($Type == 0)    # Nichts gefunden
    {
    $Config->[3] = $Buffer; # Trailer
    }
$Buffer = "";
$Type = 0;
return;
}
# -------------------------------------------------------------
# $Ok = $rCfg->ReadCfg ($File, $bIsHandle, $bKeySubst);
#
# Es werden Daten aus einer Config-Datei in das
# Config-Datei-Objekt uebernommen.
# -------------------------------------------------------------
# Parameter:
#
# $File          In    Name der oder Handle auf die Config-Datei.
# $bIsHandle     In    Falls wahr, wird in $File ein Handle erwartet.
#                      Default: falsch.
# $bKeySubst     In    Falls war, wird auch in den Schluesselworten
#                      die %%-Ersetzung vorgenommen. Default: falsch.
#
# Return:        $rCfg .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub ReadCfg
    {
    my ($Config, $CfgFile, $Handle, $KeySubst) = @_;
    my $AbsFile = $CfgFile;
    if ($CacheAvailable == 1)
        {
        if (!$Handle && (-f $CfgFile))
            {
            $AbsFile = abs_path($CfgFile);
            }
        }
    return _ReadCfg($Config, $AbsFile, $Handle, $KeySubst);
    }


sub _ReadCfg
{
my ($CfgFile, $Handle, $KeySubst);

($Config, $CfgFile, $Handle, $KeySubst) = @_;
 
 # lokale Variablen
local (*CFGFILE);
local $_;

my $In;
my $Continuation;


if (not $Handle)
    {  
    open (CFGFILE, $CfgFile) or do
        {
        $::ErrMsg = &Get(LibErrOpenConfigFile3 => $CfgFile);
        return;
        };
    $In = \*CFGFILE;
    }
else
    {
    $In = $CfgFile;
    }

# my $Sep = $Config->GetMode ("SEPARATOR"); # Separator
my ($CommentSign, $SectionNameTest, $KeyNameTest) = $Config->GetSigns ();
$Buffer = $Config->[3]; # Trailer
$Name = "";
$Type = 0;  # $Buffer ist leer
$RefSection = undef;

$bFold = $Config->GetMode("FOLDKEYCASE");
$bFold = ($bFold eq "YES");
my $autoUtf8 = $Config->GetMode("AUTOUTF8");
my $bAtStart = 1;
my $CommentExpr= quotemeta $CommentSign;
my $readUTF8 = 0;
$Config->SetModes("UTF8", "NO");
while (<$In>)
    {
    &$DBG ($_);
    $_ =~ tr/\r//d;       # CR loswerden
    if ($bAtStart && /^\357\273\277/ ) # check for 0xefbbbf UTF-8 BOM
        {
		$Config->SetModes (BomAtStart => "YES");
        if (&libcfg2::Utf8Available())
            {
            $Config->SetModes("UTF8", "YES");
            # update regexes 
            ($CommentSign, $SectionNameTest, $KeyNameTest) = $Config->GetSigns ();
            $readUTF8 = 1;
            }
        $_ = substr $_, 3;  # cut UTF-8 BOM for further regex to find sections correctly
        }
    elsif ($bAtStart)
        {
        $Config->SetModes (BomAtStart => "NO");
        }
    $bAtStart = 0;
    if ($readUTF8 && &libcfg2::Utf8Available())
        {
        eval '$_ = decode("UTF-8", $_, Encode::FB_QUIET);';
        }

    # Zeile parsen
    if (/^\s*$CommentExpr/ && ! $Continuation)
            {
            # Kommentarzeilen merken
            &_bufferout if ($Type);
            &$DBG ("save comment\n");
            $Buffer .= $_;
            }
    elsif (/^\s*$/)
            {
            # Leerzeilen ignorieren
            &_bufferout if ($Type);
            &$DBG ("save empty line\n");
            $Buffer .= $_;
            }
    elsif (/^\s*\[($SectionNameTest)\]/) # Anfang einer neuen Section
            { 
            &_bufferout if ($Type);
            $Name = $1;
            $Type = 1;
            &$DBG ("section '$Name' found\n");
            $Buffer .= $_;
            }
    elsif (!$Continuation  &&  /$KeyNameTest/) 
            {
            # Neues Schlüsselwort
            &_bufferout if ($Type);
            $Name = $1;
            if ($KeySubst)
                {
                $Name = &libcfg2::Substitute($Name, "ENV");
                }
            $Type = 2;
            &$DBG ("keyword '$Name' found\n");
            $Buffer .= $_;
            $Continuation = ( $_ =~ /\\\s*$/ );
            }
    # elsif ($Continuation  &&  /^\s*(.*)/)
    elsif ($Continuation)
            {
            # Wert (Fortsetzungszeile)
            &$DBG ("continuation line found to $Name\n");
            $Buffer .= $_;
            $Continuation = ( $_ =~ /\\\s*$/ );
            }
    else
            {
            # unbekannte Zeile - lieber aufhoeren -> $. enthält Zeilennummer des $CfgFile
            $::ErrMsg = &Get("LibErrConfigFileSyntax", "$CfgFile' line '$." );
#           warn &Get("LibWarnStrangeLine");
            carp($::ErrMsg);
            warn $_;
            return;
            }
    } # while
    # Falls wir ein Handle bekommen haben, 
    # soll sich der Aufrufer darum kümmern, dass es geschlossen wird.
    if (not $Handle) 
        {
        close $In;
        }

    # gelesene Konfigurationsdaten zurueckgeben
    &_bufferout;
    return $Config;
    }
} # READCFG
# -------------------------------------------------------------
# @SectionNames = $rCfg->GetSectionNames ();
#
# Es wird ein Array mit den Section-Namen des
# Config-Datei-Objekts zurueckgegeben.
# -------------------------------------------------------------
# Parameter:
#
# Return:        Array mit Section-Namen.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetSectionNames
    {
    my ($this) = @_;

    return (@{$this->[1]});
    }
# -------------------------------------------------------------
# @SectionKeys = $rCfg->GetSectionKeys ($SectionName);
#
# Es wird ein Array mit den Section-Key-Namen der angegebenen
# Section des Config-Datei-Objekts zurueckgegeben.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
#
# Return:        Array mit Section-Key-Namen.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetSectionKeys
    {
    my ($this, $SectionName) = @_;

    my $Section = $this->GetSection($SectionName) or return;
    return $Section->GetKeyList ();
    } # GetSectionKeys
# -------------------------------------------------------------
# @Values    = $rCfg->GetValue ($SectionName, $KeyName, $Ersetzung);
# $LastValue = $rCfg->GetValue ($SectionName, $KeyName, $Ersetzung);
#
# Gibt Informationen zum angegebenen Schluessel der angegebenen Section
# zurueck. Im Listenkontext wird ein Array mit Strings zurueckgegeben
# (der Schluessel kann in der Section mehrfach vorkommen). Im Skalarkontext
# wird ein String fuer das letzte (oder einzige) Vorkommen des Schluessels
# zurueckgegeben. Der Inhalt der Strings haengt vom Wert des Parameters
# $Ersetzung ab:
#
# "ENV"   Von allen zu diesem Vorkommen des Schluessels gehoerigen
#         Zeilen wird zunaechst ein Backslash am Ende (mit eventuell
#         folgendem Whitespace) entfernt. Anschliessend werden reine
#         Kommentar- und Leerzeilen entfernt.
#         Das Schluesselwort einschliesslich folgendem Separator und
#         Whitespace wird entfernt.
#         Jede Zeile wird nun wie folgt weiterbehandelt:
#         Ausserhalb von "" wird jedes Zeichen woertlich uebernommen,
#         ein Kommentarzeichen beendet die Uebernahme, wobei noch
#         Whitespace am Ende entfernt wird.
#         Innerhalb von "" wird jedes Zeichen woertlich uebernommen,
#         der Backslash dient als Escape: \" wird zu ", \\ wird zu \,
#         \x wird zu x. Die einschliessenden "" werden nicht uebernommen
#         (Dieses Verhalten kann mit SetModes (RETURNQUOTES => "YES")
#         geaendert werden.)
#         "" sollen immer innerhalb einer Zeile balanciert sein.
#         Die uebernommenen Zeilen werden mit einem Space verkettet.
#         Im so entstandenen String wird schliesslich die %%-Ersetzung
#         aus dem Environment vorgenommen.
#         Dies ist der Default.
# "NO"    Genau wie bei "ENV", jedoch ohne %%-Ersetzung.
# "ASIS"  Alle zu diesem Vorkommen des Schluessels gehoerigen Zeilen,
#         werden so wie sie in der Cfg-Datei stehen als ein String
#         zurueckgegeben (einschliesslich fuehrender Kommentarzeilen).
#
# Wem das zu theoretisch ist, der moege das Beispiel am Ende dieser Datei
# betrachten und ausfuehren.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
# $KeyName       In    Name des Schluessels.
# $Ersetzung     In    siehe oben und Function SetModes .
#
# Return:        Werte-Feld oder -String (siehe oben).
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetValue
    {
    my ($this, $SectionName, $KeyName, @Params) = @_;

    $Params[0] = uc ($Params[0] ? $Params[0] : $this->GetMode("GETMODE"));

    $KeyName = lc($KeyName) if($this->GetMode("FOLDKEYCASE") eq "YES");
    my $Section = $this->GetSection ($SectionName) or return;
    # wir brauchen weiter unten in den Objekten Zugriff auf das CF-Objekt!
    my @Val = $Section->GetValue ($KeyName, $this, @Params);
	
	my @DecodedVal;
	if ($this->GetMode("UTF8") eq "NO")
		{
		foreach my $val (@Val)
			{
			my $decoder = guess_encoding($val, 'utf8');
			$decoder = guess_encoding($val, 'iso-8859-1') unless ref $decoder;
			$val = $decoder->decode($val) if ref $decoder;
			push @DecodedVal, $val;
			}
		}
	else
		{
		@DecodedVal = @Val;
		}
		
    return wantarray ? @DecodedVal : $DecodedVal[-1];
    } # GetValue

sub GetComment
    {
    my ($this, $SectionName, $KeyName, @Params) = @_;

    $Params[0] = uc ($Params[0] ? $Params[0] : $this->GetMode("GETMODE"));

    $KeyName = lc($KeyName) if($this->GetMode("FOLDKEYCASE") eq "YES");
    my $Section = $this->GetSection ($SectionName) or return;
    # wir brauchen weiter unten in den Objekten Zugriff auf das CF-Objekt!
    my @Val = $Section->GetComment ($KeyName, $this, @Params);

    return wantarray ? @Val : $Val[-1];
    } # GetValue

sub GetCommentEx
    {
    my ($this, $SectionName, $KeyName, @Params) = @_;
    my $tail;
    if (!defined $SectionName)
        {
        my @SectionNames = $this->GetSectionNames();
        $SectionName = $SectionNames[0];
        $tail = $this->[3];
        }
    my $Section = $this->GetSection ($SectionName) or return;
    $KeyName = lc($KeyName) if($this->GetMode("FOLDKEYCASE") eq "YES");
    my @lines = $Section->GetCommentEx($KeyName, $this, @Params);
    if ($tail)
        {
        push @lines, [$tail];
        }
    return wantarray ? @lines : $lines[1]->[0];
    }

sub SetCommentEx
    {
    my ($this, $SectionName, $KeyName, $rl_comments, @Params) = @_;
    my $tail;
    if (!defined $SectionName)
        {
        my @SectionNames = $this->GetSectionNames();
        $SectionName = $SectionNames[0];
        if ($rl_comments->[2])
            {
            my $rl_tail =  pop @$rl_comments;
            $this->[3] = join ("\n", @$rl_tail);
            }
        }
    my $Section = $this->GetSection ($SectionName) or return;
    $KeyName = lc($KeyName) if($this->GetMode("FOLDKEYCASE") eq "YES");
    my $stat = $Section->SetCommentEx($KeyName, $this, $rl_comments, @Params);
    return $stat;
    }

# -------------------------------------------------------------
# $rSection = $rCfg->GetSection ($SectionName);
#
# Es wird eine Referenz auf die angegebene
# Section des Config-Datei-Objekts zurueckgegeben.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
#
# Return:        Referenz auf Section-Objekt.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetSection
    {
    my ($this, $SectionName) = @_;

    $SectionName ||= $DefaultSectionName;

    my $Section;

    return $Section if (($Section = $this->[2]->{$SectionName}));

    $::ErrMsg = &Get("LibErrNoSection", $SectionName);
    return;
    } # GetSection
# -------------------------------------------------------------
# Die folgenden Funktionen werden nur zum Aendern von Cfg-Dateien benoetigt.
# -------------------------------------------------------------
# $Ok = $rCfg->SetValue ($SectionName, $KeyName, $Value, $Art, $bAppend);
#
# In der angegebenen Section des Config-Datei-Objekts wird der
# Wert eines Schluessels ersetzt bzw. hinzugefuegt.
#
# Wenn der Schluessel oder die Section noch nicht existieren, werden sie
# erzeugt.
#
# Der Parameter $Art bestimmt, wie $Value gespeichert wird.
# NOQU     Der Wert wird wie uebergeben gespeichert. Enthaelt der
#          Wert allerdings # oder ", erhaelt man ihn beim spaeteren
#          Wiedereinlesen nicht richtig zurueck.
# QUOT     Im Wert werden \ und " mit \ escaped und der komplette
#          Wert wird in "" eingeschlossen. Damit erhaelt man den Wert
#          beim spaeteren Wiedereinlesen wieder genauso zurueck.
#          V o r b e h a l t: Wie andere Routinen (C-Programme die
#          CFG-Datei interpretieren, bleibt dahingestellt.
# ASIS     Hier muss $Value die komplette CFG-Zeile einschliesslich
#          Schluesselwort, Separator und abschliessendem \n enthalten.
#          Es koennen so auch mehrere Zeilen (fuehrende Kommentarzeilen,
#          Fortsetzungszeilen - alles im String $Value) erzeugt werden.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
# $KeyName       In    Name des Schluessels.
# $Value         In    Zugehoeriger Wert.
# $Art           In    siehe oben und Function SetModes .
# $bAppend       In    Falls wahr, wird neuer Wert angehaengt (Multivalue)
#                      (default: falsch).
#
# Return:        Referenz auf Section-Objekt.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub SetValue
    {
 # my ($this, $Section, $Key, $Value, @Comment) = @_;
    my ($this, $SectionName, $KeyName, $Value, $Art, $bAppend) = @_;
    if (&libcfg2::Utf8Available())
        {
        if ((utf8::is_utf8($KeyName)) || (utf8::is_utf8($Value)))
            {
            if ($this->GetMode ("BomAtStart") ne "NO")
                {
                $this->SetModes("UTF8", "YES");
                }
            else
                {
                # $Value = encode("UTF-8", $Value, Encode::FB_QUIET);
                }
            }
        }
    $Art = uc ($Art ? $Art : $this->GetMode("SETMODE"));

 # nicht existierende Section wird angelegt
    my $Section =
        $this->AddSection ($SectionName);

    if ($Art ne "ASIS")
        {
        if ($Art eq "QUOT")
            {
            $Value =~ s/([\\\"])/\\$1/g;
            $Value = qq ("$Value");
            }
        $Value = sprintf ($this->GetMode ("FORMAT") || $DefaultFormat,
                         $KeyName,
                         $this->GetMode ("SEPARATOR"),
                         $Value,
                         );
        }
    $Section->AddKey ($KeyName, $Value, ! $bAppend);
    } # SetValue
# -------------------------------------------------------------
# $rSection = $rCfg->AddSection ($SectionName, $Zeilen, $Before);
#
# Es wird eine leere Section zum Config-Datei-Objekt vor der Section
# mit Namen $Before (Default: am Ende) hinzugefuegt.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
# $Zeilen        In    Section-Zeile und Kommentarzeilen.
# $Before        In    Name der Section, vor der eingefuegt werden soll.
#                      Default: neue Section wird am Ende eingefuegt.
#
# Return:        Referenz auf Section-Objekt.
#
# Es ist kein Fehler, wenn die Section schon existiert,
# dann passiert gar nichts.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub AddSection
    {
    my ($this, $SectionName, $Zeilen, $Before) = @_;

    $SectionName ||= $DefaultSectionName;

    if (&libcfg2::Utf8Available())
        {
        if (utf8::is_utf8($SectionName))
            {
            $this->SetModes("UTF8", "YES");
            }
        }
    my $RefSection;

    if (! $Zeilen && $SectionName ne $DefaultSectionName)
        {
        $Zeilen = "\n[$SectionName]\n";
        }

    if (not ($RefSection = $this->GetSection ($SectionName)))
        {
        $this->[2]->{$SectionName} = $RefSection = "section"->New($Zeilen);
        if ($Before)
            {
            $this->[1] = _insert ($this->[1], $SectionName, $Before);
            }
        else
            {
            push (@{$this->[1]}, $SectionName);
            }
        }
    return $RefSection;
    } # AddSection
# -------------------------------------------------------------
# $rSection = $rCfg->DeleteSection ($SectionName);
#
# Die angegebene Section wird aus dem Config-Datei-Objekt geloescht.
# Der Inhalt der Section bleibt intakt und diese kann anschliessend
# mit InsertSection in ein anderes Config-Datei-Objekt eingefuegt
# werden.
# -------------------------------------------------------------
# Parameter:
#
# $SectionName   In    Name der Section.
#
# Return:        Referenz auf Section-Objekt.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub DeleteSection
    {
    my ($this, $SectionName) = @_;

    my $rhSecs = $this->[2];
        
    $SectionName ||= $DefaultSectionName;
    
    return if (! exists ($rhSecs->{$SectionName}));

    my @NewSecList =
       map ($_ eq $SectionName ? () : $_, @{$this->[1]});

    $this->[1] = \ @NewSecList;

    delete ($rhSecs->{$SectionName});
    }# DeleteSection
# -------------------------------------------------------------
# $Ok = $rCfg->InsertSection ($rSection, $SectionName, $Before);
#
# Ein Section-Objekt wird unter neuem Namen in das Config-Datei-Objekt
# eingefuegt.
# 
# Vorsicht: Wurde $rSection mit GetSection erzeugt, so entsteht dadurch
#           keine unabhaengige Kopie (vielmehr so etwas wie ein Link).
#           Zum Kopieren:
#           $rSection = Copy::copy ($rCfg->GetSection (...));
# -------------------------------------------------------------
# Parameter:
#
# $rSection      In    Referenz auf Section-Objekt.
# $SectionName   In    Name der Section.
# $Before        In    Name der Section, vor der eingefuegt werden soll.
#                      Default: neue Section wird am Ende eingefuegt.
#
# Return:        $rCfg .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub InsertSection
    {
    my ($this, $rSection, $SectionName, $Before) = @_;

    return if (ref ($rSection) ne "section");

    $SectionName ||= $DefaultSectionName;
    
    my $rhSecs = $this->[2];

    return if (exists ($rhSecs->{$SectionName}));

    if ($Before)
        {
        $this->[1] = _insert ($this->[1], $SectionName, $Before);
        }
    else
        {
        push (@{$this->[1]}, $SectionName);
        }
    $rhSecs->{$SectionName} = $rSection;
    $rSection->ChangeNameInHeader ($SectionName, $this);

    return $this;
    } # InsertSection
# -------------------------------------------------------------
# $Ok = $rCfg->ChangeSectionName ($OldName, $NewName);
#
# Der Name einer existierenden Section im Config-Datei-Objekt wird
# geaendert.
# -------------------------------------------------------------
# Parameter:
#
# $OldName       In    Alter Name.
# $NewName       In    Neuer Name.
#
# Return:        $rCfg .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub ChangeSectionName
    {
    my ($this, $OldName, $NewName) = @_;

    my $rhSecs = $this->[2];
    exists ($rhSecs->{$NewName}) and do
        {
        $::ErrMsg = &Get("LibErrNewSection", $NewName );
        return;
        };
    my $Section = delete ($rhSecs->{$OldName}) or do
        {
        $::ErrMsg = &Get("LibErrNoOldSection", $OldName);
        return;
        };

    $rhSecs->{$NewName} = $Section;
    
    foreach (@{$this->[1]})
        {
        if ($_ eq $OldName)
            {
            $_ = $NewName;
            last;
            }
        }

    $Section->ChangeNameInHeader($NewName, $this) or return;
    return $this;
    } # ChangeSectionName
# -------------------------------------------------------------
# $rCfg->SetSectionOrder (@NewSecList) == 0 or ...;
#
# Funktion definiert die Reihenfolge der Section im CFG Objekt neu
# -------------------------------------------------------------
# Parameter:
#
# @NewSecList    In    Neue Liste der Sections.
#
# Return:        0   O.K.
#                > 0 Fehler: Laenge oder Inhalt der neuen Liste
#                            stimmen nicht mit der alten ueberein.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub SetSectionOrder
    {
    my ($this, @NewSecList) = @_;

    my $OldSecRef = $this->[1];
    return (1) if (@NewSecList != @$OldSecRef);
    my %Test = ();
    my $Sec;
    foreach $Sec (@$OldSecRef, @NewSecList)
        {
        $Test{$Sec}++;
        }
    foreach $Sec (keys (%Test))
        {
        return (2) if ($Test{$Sec} != 2);
        }
    $this->[1] = \@NewSecList;
    return (0);
    } # SetSectionOrder
# -------------------------------------------------------------
# ($CommentSign, $SectionTest, $KeyTest, $Valuetest) = $rCfg->GetSigns ();
#
# Interne Function zur Ermittlung der gueltigen Zeichen.
# Zur Rueckwaertskompatibilitaet werden globale Variablen ausgewertet.
# -------------------------------------------------------------
# Return:        Siehe oben.
# -------------------------------------------------------------
# History:       06.09.1999 hf erzeugt.
# -------------------------------------------------------------
sub GetSigns
    {
    my ($this) = @_;

    my @Ret = ();

    my $s;
    
    $s = $this->GetMode ("COMMENTSIGN") || $CommentSign;
    push (@Ret, $s);

    $s = $this->GetMode ("SECTIONSIGNS") || ($this->GetMode("UTF8") eq "YES") ? $Utf8ValidSectionNameSigns : $ValidSectionNameSigns;
#   push (@Ret, "[$s]+");
    push (@Ret, "[$s]*");

    my $myValidKeyNameSigns = ($this->GetMode("UTF8") eq "YES") ? $Utf8ValidKeyNameSigns : $ValidKeyNameSigns;
    $s = $this->GetMode ("KEYRE") ||
        "^\\s*([$myValidKeyNameSigns]+)";
    push (@Ret, $s);

    $s = $this->GetMode ("VALUERE") ||
         "^\\s*[$myValidKeyNameSigns]+\\s*"
         . $this->GetMode ("SEPARATOR")
         . "\\s*(.*)";
    push (@Ret, $s);

    return @Ret;
    } # GetSigns
# -------------------------------------------------------------
# $newra = _insert ($ra, $Value, $Before);
#
# Fuegt $Value in ein Array @$ra ein und zwar vor dem ersten Element, das
# mit $Before uebereinstimmt.
# Wird kein solches Element gefunden, wird am Ende eingefuegt.
# -------------------------------------------------------------
# Parameter:
#
# $ra            In    Referenz auf Array.
# $Value         In
# $Before        In
#
# Return:        Referenz auf modifiziertes Array.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub _insert
    {
    my ($ra, $Value, $Before) = @_;

    my @NewSectionList = ();
    my $bInsert = 0;
    my $Sec;

    foreach $Sec (@$ra)
        {
        if($Sec eq $Before)
            {
            push (@NewSectionList, $Value);
            $bInsert = 1;
            }
        push (@NewSectionList, $Sec);
        }
    push (@NewSectionList, $Value) if (! $bInsert);

    return \@NewSectionList;
    } # _insert
# -------------------------------------------------------------
# $rKey = $rCfg->DeleteKey ($SectionName, $KeyName);
#
# Aus der angegebenen Section des CFG-Objekts wird der angegebene Key
# geloescht.
# -------------------------------------------------------------
# Parameter:
#
# $SectioName    In    Name der Section.
# $KeyName       In    Name des Keys.
#
# Return:        Referenz auf den geloeschten Key.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub DeleteKey
    {
    my ($this, $SectionName, $KeyName) = @_;

    my $Section = $this->GetSection ($SectionName) or return;

    $Section->DeleteKey ($KeyName);
    }
# -------------------------------------------------------------
# $NewVal = $rCfg->Append ($Value, $Neu);
#
# Hilfsfunktion: Ein CFG-Eintrag wird verlaengert (klassisches Beispiel:
# PLOTTER_SECTIONS). $Neu wird an $Value angehaengt, wobei eine Fortsetzungs-
# zeile gebildet wird. Es wird versucht die Einrueckung beizubehalten.
# -------------------------------------------------------------
# Parameter:
#
# $Value         In    CFG-Eintrag (mit GetValue(..., "ASIS") geholt)
# $Neu           In    wird angehaengt.
#
# Return:        String mit erweitertem CFG-Eintrag.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub Append
    {
    my ($this, $Value, $Neu) = @_;

    chomp ($Value);
# letzte Zeile isolieren:
    my $pos = rindex ($Value, "\n") + 1;
    my $zeile = substr ($Value, $pos);
    my $prefix = " " x 20; # wenn alles schiefgeht

    if ($Value =~ /\\/)  # schon eine Fortsetzungszeile vorhanden
        {
 # suchen nach fuehrenden Space in der letzten Zeile
        $zeile =~ /^(\s*)/ and $prefix = $1;
        }
    else
        {
        my (undef, undef, undef, $ValueTest) = $this->GetSigns ();
        $zeile =~ /$ValueTest/
            and $prefix = " " x (length ($zeile) - length ($1));
        }
    return $Value . " \\\n" . $prefix . $Neu . "\n";
    } # Append

# -------------------------------------------------------------
# $Ok = $rCfg->Write ($File, $bIsHandle);
#
# Das CFG-Objekt wird in die angegebene Datei geschrieben.
# -------------------------------------------------------------
# Parameter:
#
# $File          In    Name der oder Handle auf die Config-Datei.
# $bIsHandle     In    Falls wahr, wird in $File ein Handle erwartet.
#                      Default: falsch.
#
# Return:        $rCfg .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub Write
    {
    my ($this, $File, $Handle) = @_;

    local(*OUT);
    my $SectionName;
    my $Section;
    my $KeyName;
    my $Out;

    if (not $Handle)
        {
        my $writeUTF8 = $this->GetMode("UTF8");
        my $stat = 0;
        if ($writeUTF8 eq "YES" && &libcfg2::Utf8Available() && ($this->GetMode ("BomAtStart") ne "NO"))
            {
            eval '$stat = open(OUT,">:utf8", $File); print OUT "\x{FEFF}";';
            }
        else
            {
            $stat = open(OUT,">$File");
            }
        unless ($stat)
            {
            $::ErrMsg = &Get("OsErrFileOpenWrite", $File, "$!");
            return;
            };
        $Out = \*OUT;
        }
    else
        {
        # TODO UTF8 not supported here
        $Out = $File;
        }

    my $bSort = $this->GetMode("SORT", 1) eq "YES";

    foreach $SectionName ($this->GetSectionNames())
        {
        $Section = $this->GetSection($SectionName);
        # Sectionzeilen ausgeben
        $Section->[0] =~ s/^\n//g if $this->GetMode("NOBLANKLINES") eq "YES";
        print $Out $Section->[0];
        my @Keylist = $Section->GetKeyList();
        @Keylist = sort @Keylist if($bSort);
        foreach $KeyName (@Keylist)
            {
            my @Lines = $Section->GetValue($KeyName, $this, "ASIS");
            print $Out @Lines;
            }
        }
    print $Out $this->[3];
    if (not $Handle)
        {
        close $Out;
        }
    return $this;
    }

# -------------------------------------------------------------
# Die folgenden Functions sind eigentlich ueberfluessig, werden aber
# noch unterstuetzt.
# -------------------------------------------------------------
# $rCfg = libcfg2::new ($File, $bIsHandle, $Separator);
#
# Bitte New, ReadCfg und SetModes (RETURNQUOTES => "YES") verwenden.
# -------------------------------------------------------------
sub new
    {
    my ($File, $Handle, $Sep, $KeySubst) = @_;

    my $rCfg = libcfg2->New ($Sep);
    
# alter Aufruf - alter Rueckgabemodus

    $rCfg->SetModes (RETURNQUOTES => "YES");

    $File ? $rCfg->ReadCfg ($File, $Handle, $KeySubst) : $rCfg;
    }
# -------------------------------------------------------------
# $Ok = $rCfg->AddValue ($SectionName, $KeyName, $Value, $Art, $bAppend);
#
# Bitte SetValue verwenden (Parameter $bAppend = 1).
# -------------------------------------------------------------
sub AddValue
    {
 # my ($this, $Section, $Key, $Value, @Comment) = @_;
 # my ($this, $SectionName, $KeyName, $Value, $Art, $bAppend) = @_;
    my $this = shift (@_) ;

    $_[4] = 1;
    $this->SetValue (@_);
    } # AddValue
# -------------------------------------------------------------
# @Values = $rCfg->GetMultiValue ($SectionName, $KeyName, $Ersetzung);
#
# Bitte GetValue im Listenkontext verwenden.
# -------------------------------------------------------------
sub GetMultiValue
    {
 # my ($this, $Section, $Key, $Ersetzung) = @_;
    my $this = shift (@_) ;

    $this->GetValue (@_);
    }
# -------------------------------------------------------------
# bis hierher ueberarbeitet.
# -------------------------------------------------------------
# Die folgenden Funktionen wurden (bisher) unveraendert uebernommen.
# -------------------------------------------------------------
# Die Funktion ersetzt im Angegebenen String Variablen der Form
# %Variable% durch ihren Wert. Voraussetzung ist ein Hash, in 
# dem die zu ersetzende Variable vorkommt.
# Beispiel: %HOME% wird durch den Wert von $ENV{HOME} ersetzt
# Doppeltes % dient als Escape =>
# Beispiel: %%HOME%% wird durch den String "$ENV{HOME}" ersetzt
# Die Ersetzung kann durch den 2. Parameter gesteuert werden:
# Default fuer den 2. Parameter ist "%VAR%" und somit wird aus 
# "%%HOME%%" -> "%HOME%". Bei "\$ENV{VAR}" als 2. Parameter wird aus 
# "%%HOME%%" -> "$ENV{HOME}". "VAR" repraesentiert den Variablennamen, die
# Prozentzeichen werden nicht gemerkt => sie muessen explizit angegeben 
# werden, wenn sie im Ergebnis auch auftreten sollen.
# -------------------------------------------------------------
# Parameter: $_[0] String mit Variablen
#            $_[1] Beschreibung der Ersetzung in Perl-Notation
#                  optionaler Parameter, Default ist "\$ENV{VAR}"
# Return:    String mit ersetzten Variablen
# -------------------------------------------------------------
# History:   03.06.98 tk erstellt (von irgendwoher uebernommen)
#            21.09.98 tk durch funktionierende Version ersetzt
#            05.10.98 tk '\' in Variablen durch '\\' ersetzt
#            13.11.98 tk Defaultersetzung bei "%%VAR%%" ist jetzt
#                        "%VAR%" 
#                        Mehrere Vorkommen pro Zeile werden ersetzt
# -------------------------------------------------------------
sub Substitute
{
    my ($Line, $Replacement) = @_;
    my ($Replace, $Var);
    my $Placeholder = "~§§~";
    my $rl_options = $Replacement if (ref $Replacement eq "HASH");
    $Line =~ s/%%(\w+)%%/$Placeholder$1$Placeholder/go;
    $Line =~ s/%(\w+)%/&ReplaceVar($1, $rl_options)/geo;
    $Line =~ s/$Placeholder(\w+)$Placeholder/%$1%/go;
    return $Line;
}

    # Helper Funktion für Substitute
    sub ReplaceVar
        {
        my ($Var, $rl_options) = @_;
        my $Replacement;
        if (defined $rl_options->{$Var})
            {
            # replace from options
            $Replacement = $rl_options->{$Var};
            }
        else
            {
            #replace from environment
            $Replacement = $ENV{$Var};
            }
        if ($Replacement)
            {
            return $Replacement;
            }
        return "\%$Var\%";
        }

# -------------------------------------------------------------
# Funktion gibt einen Wert aus einem CFG Objekt zurueck
# -------------------------------------------------------------
# Parameter: $_[0] Referenz auf den Inhalt der CFG
#            $_[1] Section die den Wert enthaelt
#            $_[2] Name des Werts
#            $_[3] Trennzeichen zwischen den Werten, default ' '
# Return:    Array mit allen Inhalten des Werts
#            undef, falls ein Fehler aufgetreten ist
# -------------------------------------------------------------
# History:   14.08.98 wl erzeugt
# -------------------------------------------------------------
sub GetArrayValue
    {
    my ($this, $Section, $Key) = @_;
    my ($Value, @ValueList);
    if ($Section eq "") # Falls es Keys auserhalb der Sections gibt
        {
        $Section = "_NONE"; # liegen sie in dieser
        }
    # Wert lesen
    # aufspalten nach Trennzeichen
    print &Get("LibErrFuncNotImplemented");
    
    return @ValueList;
    }
# -------------------------------------------------------------
# Testet, ob ein String als Sektionsname geeignet ist. Dabei 
# wird nur auf Zulaessigkeit der einzelnen Zeichen getestet.
# -------------------------------------------------------------
# Parameter: $_[0] Name der Sektion
#            $_[1] Flag fuer Ausgaben auf STDERR
# Return:    1     Name ist als Sektionsname geeignet
#            0     Name ist als Sektionsname nicht geeignet
# -------------------------------------------------------------
# History:   15.09.98 tk erzeugt
#            20.04.99 hf Kopiert von libcfg.pl und angepasst
#
# -------------------------------------------------------------
sub TestSectionName
    {
    my ($SectionName, $bOutput) = ($_[0], $_[1]);

    # in $SectionNameTest stehen alle zulaessigen Zeichen und 
    # die zulaessige Laenge
#   if ($SectionName =~ /^[$ValidSectionNameSigns]+$/)
    if ($SectionName =~ /^[$ValidSectionNameSigns]*$/)
        {
        return 1;
        }
    else
        {
        if ($bOutput)
            {
            print STDERR &Get("LibInvalidSection", $SectionName, $ValidSectionNameSigns);
            }
        return 0;
        }
    }

sub parseComments
    {
    my ($this, $comments) = @_;

    my ($CommentSign, $SectionNameTest, $KeyNameTest, $ValueTest) = $this->GetSigns ();

#   Aufspalten in einzelne Zeilen und \ am Ende weg

    my @lines = split /\\?\s*\n/ , $comments;

#   Zeilen mit Kommentar heraussuchen
    my $CommentExpr= quotemeta $CommentSign;
    @lines = grep /$CommentExpr/, @lines;

#   Nun muessen wir uns noch nicht Kommentare aus den Zeilen entfernen
#   Dazu benutzen wir aber keine re's mehr.
    my $Comments = [];
    my $trailerComments = [];
    my $line;
    my $StartComment;
    my $found = 0;
    my $key = "";
    foreach $line (@lines)
        {
        # Anfang des Kommentars suchen und ab da ausschneiden
        if ($line !~ /^\s*$CommentSign/)
            {
            # keep leading blanks if this is a pure comment line
            $StartComment = $this->findComment($line, $CommentSign);
            $key =  substr($line, 0, $StartComment - 1);
            $line = substr($line, $StartComment);
            if ($key =~ /$KeyNameTest/ || $key =~ /^\s*\[($SectionNameTest)\]/)
                {
                $found = 1;
                }
            }
        if ($found)
            {
            push @$trailerComments, $line;
            }
        else
            {
            push @$Comments, $line;
            }
        }
        
    return ($Comments,$trailerComments);
    }

sub mergeComments
    {
    my ($this, $Ret, $rl_newComments) = @_;
    my $stat;

    my ($CommentSign, $SectionNameTest, $KeyNameTest, $ValueTest) = $this->GetSigns ();

    #   Aufspalten in einzelne Zeilen und \ am Ende weg
    my @lines = split /\\?\s*\n/ , $Ret;

    my $line;
    my $key = "";
    my $StartComment; 
    my $hasTrailer = 0;
    # 
    my $rl_leadingComments = $rl_newComments->[0];
    my $rl_trailingComments = $rl_newComments->[1];
    if (scalar @$rl_trailingComments > 0 )
        {
        $hasTrailer = 1;
        }
    my @newLines;
    push @newLines, @$rl_leadingComments;
    foreach $line (@lines)
        {
        # Anfang des Kommentars suchen und ab da ausschneiden
        if ($line !~ /^\s*$CommentSign/)
            {
            # keep leading blanks if this is a pure comment line
            $StartComment = $this->findComment($line, $CommentSign);
            if ($StartComment > 0)
                {
                $key =  substr($line, 0, $StartComment);
                }
            else
                {
                $key = $line;
                }
            if ($key =~ /$KeyNameTest/)
                {
                # this is a line containing a key
                if ($hasTrailer && $key =~ /\S$/)
                    {
                    $key .= " ";
                    }
                $line = "$key@$rl_trailingComments\n";
                }
            elsif ($key =~ /^\s*\[($SectionNameTest)\]/)
                {
                # this is a line containing a section
                if ($hasTrailer && $key =~ /\S$/)
                    {
                    $key .= " ";
                    }
                $line = "$key@$rl_trailingComments\n";
                }
            push @newLines, $line;
            }
        }

    return wantarray ? @newLines : join ("\n", @newLines);
    }

sub findComment
    {
    my ($rCfg, $line, $CommentSign) = @_;
    my $bQuotes = 1;
    my @charar;
    my @charar2;
    my $quoted;
    my $lastquoted;
    my $c;
    my $unicode = 0;
    if (($rCfg->GetMode("UTF8") eq "YES") && &libcfg2::Utf8Available())
        {
        $unicode = 1;
        }
        if ($unicode)
            {
            @charar = unpack ("U*", $line);
            }
        else
            {
            @charar = unpack ("C*", $line);
            }
        @charar2 = ();
        $quoted = 0;
        $lastquoted = -1;
        while ($c = shift (@charar))
            {
            if (not $quoted)
                {
                last if ($c == ord ($CommentSign));
                if ($c == ord ("\""))
                    {
                    $quoted = 1;
                    push (@charar2, $c) if ($bQuotes);
                    next;
                    }
                push (@charar2, $c);
                }
            else
                {
                # \x wird zu x fuer jedes x
                if (! $bQuotes && $c == ord ("\\"))
                    {
                    push (@charar2, shift (@charar));
                    }
                elsif ($c == ord ("\""))
                    {
                    push (@charar2, $c) if ($bQuotes);
                    $lastquoted = $#charar2;
                    $quoted = 0;
                    }
                else
                    {
                    push (@charar2, $c);
                    }
                }
            }
    return scalar @charar2;
    }

# ---------------------------------------------------------------------
# Hash-Array mit Versionsabhaengigkeiten der Bibliothek
# Sie kann von Aussen mit %<libname>::LibDependeny erfragt werden
# Beispiel: %LibDependency = %libcfg2::LibDependency;
# ---------------------------------------------------------------------
1;
}
###########################
#split section
{
package section;

use strict;
use integer;

 # use MultiKey;
# -------------------------------------------------------------
# Funktion zum erzeugen eines zunaechst leeren Section Objekts
#   $Ref  =  [
#              $Sectionzeile,
#              [ $Key ... ],
#              {
#                $Key => $MultiKeyRef,
#                ...
#              },
#            ]
# -------------------------------------------------------------
# Parameter: $_[0] Klasse
#            $_[1] Sectionzeile mit Kommentaren
# Return:    Referenz auf das leere Section Objekt
#            undef, falls ein Fehler aufgetreten ist
# -------------------------------------------------------------
# History:   19.05.99 hf erzeugt
# -------------------------------------------------------------
sub New
    {
    my ($Class, $Zeile) = @_;

    my $Ref = [
                $Zeile,
                [],
                {},
              ];
    bless ($Ref, $Class);
    return $Ref;
    }
# -------------------------------------------------------------
# Funktion gibt ein MultiKey-Objekt zurueck
# -------------------------------------------------------------
# Parameter: $_[0] Referenz auf den Inhalt der Section
#            $_[1] Name des Keys
# Return:    Key-Objekt
# -------------------------------------------------------------
# History:   19.05.99 hf erzeugt
# -------------------------------------------------------------
sub GetKey
    {
    my ($this, $KeyName) = @_;

    return $this->[2]->{$KeyName};
    }

# -------------------------------------------------------------
# Funktion zum einfuegen eines Schluessels in die Section
# -------------------------------------------------------------
# Parameter: $_[0] Section Referenz
#            $_[1] Keywordname
#            $_[2] Keywordzeile
#            $_[3] Falls wahr, wird ueberschrieben statt hinzugefuegt.
# Return:    $_[0]
# -------------------------------------------------------------
# History:   19.05.99 hf erzeugt
# -------------------------------------------------------------
sub AddKey
    {
    my ($this, $Name, @Params) = @_;

    my $MKeyRef;
    if (! ($MKeyRef = $this->GetKey($Name)))
        {
        $this->[2]->{$Name} = $MKeyRef = MultiKey->New();
        push (@{$this->[1]}, $Name);
        }
    $MKeyRef->AddKey(@Params);
    return $this;
    }
# -------------------------------------------------------------
# Funktion zum auslesen der Liste der in der Section 
# enthaltenen Keys
# -------------------------------------------------------------
# Parameter: $_[0] Section Referenz
# Return:    Liste von Key-Objekten
# -------------------------------------------------------------
# History:   12.04.99 wl erzeugt
# -------------------------------------------------------------
sub GetKeyList
    {
    my ($this) = @_;

    return @{$this->[1]};
    }

# -------------------------------------------------------------
# Funktion zum auslesen der Zeilen des angegebenen Schluessels
# -------------------------------------------------------------
# Parameter: $_[0] Section Referenz
#            $_[1] Keyword Name
#            $_[2] Ersetzen von Variablen in den gelesenen Werten
#                  1 = ersetzen (default), 0 = nicht ersetzen
# Return:    -
# -------------------------------------------------------------
# History:   25.01.99 wl erzeugt
# -------------------------------------------------------------
sub GetValue
    {
    my ($this, $KeyName, @Params) = @_;

    my $Key = $this->GetKey($KeyName) or return;
    
#nur bis die falschen alten Aufrufe ausgemerzt sind:
    if (ref ($Params[0]) ne "libcfg2")
        {
        die (&libcfg2::Get("LibErrCallGetValue"));
        }

    my @Lines = $Key->GetValue(@Params);
    return @Lines;
    }

# -------------------------------------------------------------
# Funktion zum auslesen der Kommentare des angegebenen Schluessels
# -------------------------------------------------------------
# Parameter: $_[0] Section Referenz
#            $_[1] Keyword Name
# Return:    -
# -------------------------------------------------------------
# History:   07.09.2004 wl erzeugt
# -------------------------------------------------------------
sub GetComment
    {
    my ($this, $KeyName, @Params) = @_;

    my $Key = $this->GetKey($KeyName) or return;
    
#nur bis die falschen alten Aufrufe ausgemerzt sind:
    if (ref ($Params[0]) ne "libcfg2")
        {
        die (&libcfg2::Get("LibErrCallGetValue"));
        }

    my @Lines = $Key->GetComment(@Params);
    return @Lines;
    }

sub GetCommentEx
    {
    my ($this, $KeyName, $rCfg, @Params) = @_;
    my @Lines;
    if (defined $KeyName)
        {
        my $Key = $this->GetKey($KeyName) or return;
        @Lines = $Key->GetCommentEx($rCfg, @Params);
        }
    else
        {
        @Lines = $rCfg->parseComments($this->[0]);
        }
    return @Lines;
    }

sub SetCommentEx
    {
    my ($this, $KeyName, $rCfg, $rl_Comments, @Params) = @_;
    my @Lines;
    my $stat;
    if (defined $KeyName)
        {
        my $Key = $this->GetKey($KeyName) or return;
        $stat = $Key->SetCommentEx($rCfg, $rl_Comments, @Params);
        }
    else
        {
        $this->[0] = $rCfg->mergeComments($this->[0], $rl_Comments);
        $stat = 0;
        }
    return $stat;
    }

# -------------------------------------------------------------
# $rKey = $rSec->DeleteKey ($KeyName);
#
# Der angegebene Key wird aus der Section geloescht.
# -------------------------------------------------------------
# Parameter:
#
# $KeyName       In    Name des Keys.
#
# Return:        Referenz auf Key-Objekt.
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub DeleteKey
    {
    my ($this, $KeyName) = @_;

    my $rhKeys = $this->[2];
        
    if (! exists ($rhKeys->{$KeyName}))
        {
        $::ErrMsg = &libcfg2::Get("LibErrNoKey", $KeyName);
        return;
        }

    my @NewKeyList =
       map ($_ eq $KeyName ? () : $_, @{$this->[1]});

    $this->[1] = \ @NewKeyList;

    delete ($rhKeys->{$KeyName});
    }# DeleteKey
# -------------------------------------------------------------
# $Ok = $rSec->ChangeNameInHeader ($NewName);
#
# Der Name im Section-Header (der in []) wird geaendert. Die
# Verwaltungseintraege bleiben unberuehrt. Das braucht man fuer
# Insertsection.
# -------------------------------------------------------------
# Parameter:
#
# $NewName       In    Neuer Name der Section.
# $rCfg          In    Referenz auf CFG-Objekt (wegen GetSigns).
#
# Return:        1 .
# -------------------------------------------------------------
# History:       10.08.1999 hf erzeugt.
# -------------------------------------------------------------
sub ChangeNameInHeader
    {
    my ($this, $NewName, $rCfg) = @_;

    my (undef, $SectionNameTest) = $rCfg->GetSigns ();

    $this->[0] =~ s/^(\s*)\[($SectionNameTest)\]/$1\[$NewName\]/m ;

    }# ChangeNameInHeader

1;
}
###########################
#split MultiKey
{
package MultiKey;

 # use keyword;

use strict;
use integer;

# -------------------------------------------------------------
# Funktion zum erzeugen eines MultiKey Objekts
#   $Ref  =  [ $KeyRef ... ]
#
# -------------------------------------------------------------
# Parameter: $_[0] Klasse
# Return:    Referenz auf das MultiKey Objekt
# -------------------------------------------------------------
# History:   19.05.99 hf erzeugt
# -------------------------------------------------------------
sub New
    {
    my ($Class) = @_;

    my $Ref = [];
    bless ($Ref, $Class);
    return $Ref;
    }

sub AddKey
    {
    my ($this, $Zeilen, $bReplace) = @_;

    my $rKey = "keyword"->New($Zeilen);

    if ($bReplace)
        {
        @$this = ($rKey);
        }
    else
        {
        push (@$this, $rKey);
        }
    return $this;
    }

# -------------------------------------------------------------
# Funktion zum lesen des Werts eines Schluessels
# -------------------------------------------------------------
# Parameter: $_[0] Key-Objekt
# Return:    String mit dem Inhalt des Keys
# -------------------------------------------------------------
# History:   20.01.99 wl erzeugt
# -------------------------------------------------------------
sub GetValue
    {
    my ($this, @Params) = @_;

    my @Ret;

    foreach my $Key (@$this)
        {
        push (@Ret, $Key->GetValue(@Params));
        }
    return @Ret;
    }

# -------------------------------------------------------------
# Funktion zum lesen des Werts eines Schluessels
# -------------------------------------------------------------
# Parameter: $_[0] Key-Objekt
# Return:    String mit dem Inhalt des Keys
# -------------------------------------------------------------
# History:   20.01.99 wl erzeugt
# -------------------------------------------------------------
sub GetComment
    {
    my ($this, @Params) = @_;

    my @Ret;

    foreach my $Key (@$this)
        {
        push (@Ret, $Key->GetComment(@Params));
        }
    return @Ret;
    }


sub GetCommentEx
    {
    my ($this, $rCfg, @Params) = @_;

    my @Ret;
    foreach my $Key (@$this)
        {
        my @comments = $Key->GetCommentEx($rCfg, @Params);
        push (@Ret, @comments);
        }
    return @Ret;
    }

sub SetCommentEx
    {
    my ($this, $rCfg, $rl_comments, @Params) = @_;

    my $stat = 0;
    my @comments;
    foreach my $Key (@$this)
        {
        @comments = splice(@$rl_comments, 0, 2); # fill the comments for the first occurence
        $stat |= $Key->SetCommentEx($rCfg, \@comments, @Params);
        }
    return $stat;
    }

1;
}
###########################
#split keyword
{
package keyword;

use strict;
use integer;

# -------------------------------------------------------------
# Funktion zum erzeugen eines Keyword Objekts
#   $Ref  =  \$String;
#
#   $String enthaelt alle Zeilen einschliesslich Kommentaren zu
#   diesem Keyword-Eintrag. Das Keyword kommt einmal vor!!!
# -------------------------------------------------------------
# Parameter: $_[0] Klasse
#            $_[1] Zeilenstring
# Return:    Referenz auf das Keyword Objekt
# -------------------------------------------------------------
# History:   19.05.99 hf erzeugt
# -------------------------------------------------------------
sub New
    {
    my ($Class, $Zeilen) = @_;

    my $Ref = \$Zeilen;
    bless ($Ref, $Class);
    return $Ref;
    }

sub GetValue
    {
    my ($this, $rCfg, $Ersetzung) = @_;

    my $Ret = $$this;

    return $Ret if ($Ersetzung eq "ASIS");

#    my $Sep = $rCfg->GetMode ("SEPARATOR");
    my $bQuotes = $rCfg->GetMode ("RETURNQUOTES", 1) eq "YES";
    my ($CommentSign, undef, undef, $ValueTest) = $rCfg->GetSigns ();

#   Aufspalten in einzelne Zeilen und \ am Ende weg

    my @lines = split /\\?\s*\n/ , $Ret;

#   Kommentar- und Leerzeilen entfernen
    my $CommentExpr= quotemeta $CommentSign;
    @lines = grep {
                    ! /^\s*$CommentExpr/
                    && ! /^\s*$/
                  } @lines;
#   Die erste Zeile sollte nun das Schluesselwort enthalten: weg damit.
    if ($lines[0] =~ /$ValueTest/)
        {
        $lines[0] = $1;
        }
    else
        {
        $lines[0] = ""; # empty value
        }

    #    $lines[0] =~ s/^\s*$KeyNameTest\s*$Sep\s*// ;
    #   Nun muessen wir uns noch um Kommentare ausserhalb von "" usw. kuemmern
    #   Dazu benutzen wir aber keine re's mehr.
    my @charar;
    my @charar2;
    my $quoted;
    my $lastquoted;
    my $c;
    my $line;
    my $unicode = 0;
    if (($rCfg->GetMode("UTF8") eq "YES") && &libcfg2::Utf8Available())
        {
        $unicode = 1;
        }
    foreach $line (@lines)
        {
        if ($unicode)
            {
            @charar = unpack ("U*", $line);
            }
        else
            {
            @charar = unpack ("C*", $line);
            }
        @charar2 = ();
        $quoted = 0;
        $lastquoted = -1;
        while ($c = shift (@charar))
            {
            if (not $quoted)
                {
                last if ($c == ord ($CommentSign));
                if ($c == ord ("\""))
                    {
                    $quoted = 1;
                    push (@charar2, $c) if ($bQuotes);
                    next;
                    }
                push (@charar2, $c);
                }
            else
                {
                # \x wird zu x fuer jedes x
                if (! $bQuotes && $c == ord ("\\"))
                    {
                    push (@charar2, shift (@charar));
                    }
                elsif ($c == ord ("\""))
                    {
                    push (@charar2, $c) if ($bQuotes);
                    $lastquoted = $#charar2;
                    $quoted = 0;
                    }
                else
                    {
                    push (@charar2, $c);
                    }
                }
            }
# Jetzt schmeissen wir noch unquotierten Whitespace am Ende weg

        pop (@charar2)
            while ($#charar2 > $lastquoted &&
                (($c = $charar2[-1]) == ord (" ")
                || $c == ord ("\t")));

        # 2010-05-04, ss: DON'T OPTIMIZE FOLLOWING LINES
        # pack seems to be broken if you use pack($template, @charar2)
        # and sets UTF8 bit in perl string where no utf8 is inside, found in EDC
        if ($unicode)
            {
            $line = pack ("U*", @charar2);
            }
        else
            {
            $line = pack ("C*", @charar2);
            }
        }
    $Ret = join (" ", @lines);
    
    return $Ret if ($Ersetzung eq "NO");

    $Ersetzung ||= "ENV";
    $Ret = &libcfg2::Substitute($Ret, $Ersetzung);
#    if (! $unicode && utf8::is_utf8($Ret))
#        {
#        my $break = 1;
#        print "UUUUHHHAAA\n";
#        }
    return $Ret;
    
    }

sub GetComment
    {
    my ($this, $rCfg) = @_;

    my $Ret = $$this;
    # my @Comments = $rCfg->parseComments($Ret);

    my ($CommentSign, undef, undef, $ValueTest) = $rCfg->GetSigns ();

#   Aufspalten in einzelne Zeilen und \ am Ende weg

    my @lines = split /\\?\s*\n/ , $Ret;

#   Zeilen mit Kommentar heraussuchen
    my $CommentExpr= quotemeta $CommentSign;
    @lines = grep /$CommentExpr/, @lines;

#   Nun muessen wir uns noch nicht Kommentare aus den Zeilen entfernen
#   Dazu benutzen wir aber keine re's mehr.
    my @Comments;
    my $line;
    my $StartComment;
    foreach $line (@lines)
        {
        # Anfang des Kommentars suchen und ab da ausschneiden
        $StartComment = index($line, $CommentSign);
        $line = substr($line, $StartComment + 1);
# Jetzt schmeissen wir noch unquotierten Whitespace am Ende weg
        $line =~ s/\s+$//;
        $line =~ s/^\s+//;
        push @Comments, $line;
        }
        
    $Ret = join ("\n", @Comments);

    return $Ret;
    
    }
    
sub GetCommentEx
    {
    my ($this, $rCfg, @Params) = @_;

    my $Ret = $$this;
    return $rCfg->parseComments($Ret);
    }

sub SetCommentEx
    {
    my ($this, $rCfg, $rl_comments, @Params) = @_;

    my $Ret = $$this;
    $$this = $rCfg->mergeComments($Ret, $rl_comments);
    return 0;
    }
1;
}
###########################
#split Copy
{
package Copy;
# Package zum Kopieren einer (fast) beliebigen Datenstruktur

sub copy
{
my ($this) = @_;

ref ($this) or return $this;

my $sthis = "$this";
my $pos = -1;
my $type = "";

SUCHEN: {
my $i;
my @typen = qw (ARRAY HASH SCALAR);

my $key;
foreach $key (@typen)
    {
    if (($i = rindex ($sthis, $key)) > $pos)
        {
        $pos = $i;
        $type = $key;
        }
    }
if (not $type)
    {
    warn (&libcfg2::Get("LibWarnNoCopy", $sthis, "@typen"));
    return;
    }
} # SUCHEN

if($type eq "ARRAY")
    {
    my @newar = map {
                 copy ($_);
                 } @$this;
    $ret = \@newar;
    }
elsif($type eq "HASH")
    {
    my %newhash = %$this;
    my $key;
    foreach $key (keys (%newhash))
        {
        $newhash{$key} = copy ($newhash{$key});
        }
    $ret = \%newhash;
    }
else
    {
    my $newsc = copy($$this);
    $ret = \$newsc;
    }

if ($pos > 0) # $this war geblesst
    {
    bless ($ret, substr ($sthis, 0, $pos-1));
    }
return $ret;
}

1;
}

__END__

=pod

=head1 NAME

libcfg2

=head1 SYNOPSIS

 use libcfg2;

 #create empty config-file-object
 libcfg2::useCachedFiles() # enable cached file reads
 my $Ini = libcfg2->New();
 
 #set no replacement mode
 $Ini->SetModes(GETMODE => "NO");
 
 #commit the contents of _IniFile_ to config-file-object
 $Ini->ReadCfg('$IniFile');
 
 #read section names
 my @sections = $Ini->GetSectionNames();
 
 #iterate through sections
 foreach my $section (@sections) {
 
    #read section-key-names from the current section of 
    #the config-file-object
    my @keys = $Ini->GetSectionKeys($section);

    #iterate through keys
    foreach my $key (@keys) {
    
        #get the value of the key
        my $val = $Ini->GetValue($section, $key);
        
        #display value
        Log($val, 'I')
    }
 } 

=head1 DESCRIPTION

 This module allows to read and write files in
 PLOSSYS-INI format.

=head2 FUNCTIONS

=over

=item *

 New($Sep)
 An empty config-file-object is created.

 $Sep - separator (Default: "=")
 
 returnvalue - empty config-file-object

=item *

 SetModes(MODE => $Value, ...)
 This function influences the behavior of GetValue/SetValue regarding
 value interpretation.

 MODE - see "MODES" below
 $Value - value of MODE
 
 returnvalue - config-file-object
 
 MODES
 
 GETMODE     replacement mode for the GetValue function
             possible Values: ENV, NO, ASIS
 SETMODE     value interpretation mode for the SetValue function
             possible Values: NOQU, QUOT, ASIS
 SEPARATOR   separator character
             it is used in these cases:
             on reading: in R.E., if KEYRE is empty
             in GetValue:  in R.E, if KEYRE is empty
             in SetValue:  as string
 FORMAT      output format for SetValue
             This way 3 variables keyword, separator character, value 
             are displayed.
             Default: "  %-20s %s %s\n" - dont forget \n !
 FOLDKEYCASE The name of the key in GatValue and GetComment is changed to
             lower case.
 The next 4 mode values a empty by default. Old global variables are 
 used in this case. The sytax check can defined the object oriented way 
 though.
 COMMENTSIGN  This character starts a comment.
 SECTIONSIGNS A string with all characters, that are valid in sectionnames.
 KEYRE        This R.E. is used to seach for keyvalues while reading. On a 
              match the part in brackets becomes the new keyvalue.
              The whole line is saved though including preceding comentlines
              and the following lines.
 VALUERE      With this R.E. a value is determined in GetValue. The R.E. is 
              applied on the first saved noncomment line (without \ and \n), 
              it actually serves to mask the keyvalue.
              On a match the part in brackets becomes the new value, which 
              is expanded with following lines though.
 RETURNQUOTES YES " and \ in " quotes are returned (old mode)
              NO  " are not returned and \ in " quotes are treated as escape
              characters (Default, but it is set to YES, if initialised per 
              new. 
 SORT         YES The keys withhin an section are displayed in order.
              NO  The keys are displayed in the same order, as they are
              saved in the hash.

=item *

 GetMode($ModeKey, $bUc)
 This function sends a query for mode settings for a cfg-object.
 
 $ModeKey - keyword
 $bUc - if true, the value is turned to upper case
 
 returnvalue - associated value

=item *

 ReadCfg($CfgFile, $Handle, $KeySubst)
 Data from a config file is parsed into the config-data-object.
 To speed up multiple file read operation use method
 libcfg2::useCachedFiles() to enable cached file reads
 
 $CfgFile - name or handle to the config file
 $Handle - if true, a handle is expected in $CfgFile
           false is default
 $KeySubst - if true, the %%-replacement also occurs in keywords
             false is default

 returnvalue - config-file-object

=item *

 GetSectionNames()
 This function writes the section names from a config-file-object into 
 an array.
 
 no parameters
        
 returnvalue - array containig the section names

=item *

 GetSectionKeys($SectionName)
 This function writes the section-key-names of the selected section from 
 the config-file-object into an array.
 
 $SectionName - name of the section
        
 returnvalue - array containig the section-key-names

=item *

 GetValue($SectionName, $KeyName, $Ersetzung)
 This function returns information about the selected key of the selected 
 section. In array context an array of strings is returned. (A key can 
 appear more often than once in a section. In scalar context a string for 
 the last (or the only) appearance of the key is returned. The content of 
 the string depends on the value of the $Ersetzung parameter:
 
 "ENV" First a backslash (and the optionally following whitespace) is 
 deleted from the end of all lines, that belong to this appearance of 
 the key. Then pure comment and empty lines are deleted.
 The keyword including the following separator and whitespace is deleted.
 Now each line is treated like this:
 Outside of " quotes each character is transfered literally, a comment 
 character ends the transfer, at which whitespace from the end of line 
 is deleted.
 Outside of " quotes each character is transfered literally, the 
 backslash is used to escape characters: \" becomes ", \\ becomes \ and 
 \x becomes x. The enclosing " quotes are not taken over (This behaviour 
 can be changed by SetModes (RETURNQUOTES => "YES").)
 " quotes should always be balanced within one line.
 The assumed lines are linked with a space. The %%-replacement in the 
 resulting string is finally conducted from the environment. This is 
 the default setting.
 "NO" just like "ENV" except the $$-replacement
 "ASIS" All characters that belong to the current appearance of the key 
 are returned (preceding comment lines are included) in the same order 
 as in the cfg-file.
 
 $SectionName - name of the section
 $KeyName - name of the key
 @Ersetzung - see above and function SetModes
 
 returnvalue - array of values or value as string (see above)

=item *

 GetComment($SectionName, $KeyName, $Ersetzung)
 This function determines the comment line after the Value corresponding to 
 the selected key.
 
 $SectionName - name of the section
 $KeyName - name of the key
 @Ersetzung - see above and function SetModes

 returnvalue - comment line

=item *

 GetCommentEx($SectionName, $KeyName)
 This function determines the comment line after the Value corresponding to 
 the selected key. If SectionName and KeyName are left out, the function determines 
 leading and trailing comments of the complete file 
 
 $SectionName - name of the section
 $KeyName - name of the key

 returnvalue - array containing two array refs. The fist contains all 
               comments in front of the value, the second one contains
               all comments in the same line as the value
             - if no options given a third arrayref containing all trailing
               comments is passed
             - if the given key is a multivalue key, two arrayrefs are returned for each value  
=item *

 SetCommentEx($SectionName, $KeyName, $rl_comments)
 This function sets comments the Value corresponding to 
 the selected key. If SectionName and KeyName are left out, the function sets 
 leading and trailing comments of the complete file 
 
 $SectionName  - name of the section
 $KeyName      - name of the key
 $rl_comments  - arrayref containing the comments to be set
                 the arrayref can be taken from previous calls 
                 to GetCommentEx() s.o. 

 returnvalue -  0 if OK

=item *

 GetSection($SectionName)
 This function creates a reference to the selected section of the 
 config-file-object.
 
 $SectionName - name of the section
 
 returnvalue - reference to the section-object

=item *

 SetValue($SectionName, $KeyName, $Value, $Art, $bAppend)
 This function changes or adds the value of a key in the selected 
 section of the config-file-objects. If the key or the section does not 
 exist yet, it is created. The parameter $Art defines how $Value 
 is stored:
 
 NOQU The Value is stored just like it is commited. If it contains 
 # or ", it cannot be read correctly again.
 QUOT Within the Value \ and " are escaped with \ and the whole value 
 is enclosed in " quotes. This way the value can be read correctly again.
 E x c e p t i o n: Other routines (c-programs) may interpret the 
 cfg-file otherwise.
 
 ASIS In this case $Value must contain the whole cfg-line including keyword, 
 separator and closing \n. This way several lines (preceding commentlines, 
 following lines - everything in the $Value string) can be created at once.
 
 $SectionName - name of the section
 $KeyName - name of the key
 $Value - corresponding value
 $Art - see above and function SetModes
 $bAppend - if true, new value is appended
            false is default

 returnvalue - reference to the section-object

=item *

 AddSection($SectionName, $lines, $Before)
 This function adds an empty section to the config-file-object before 
 the section set in $Before.
 
 $SectionName - name of the section
 $lines - section-line and comment-lines
 $Before - the empty section will should be added before this section
           by default the empty section is appended
 
 returnvalue - reference to the section-object
 
 If the section does not exist, then nothing happens.
 It is not an error.

=item *

 DeleteSection($SectionName)
 This function deletes the selected section from the config-file-object.
 The content of the section remains intact and can afterwards be inserted 
 into an other config-file-object with InsertSection.
 
 $SectionName - name of the section
 
 returnvalue - reference to the section-object

=item *

 InsertSection($rSection, $SectionName, $Before)
 This function inserts a section-object into a config-file-object using 
 a new name.
 Warning: If $rSection was created with GetSection, no independent copy 
 is created (rather a kind of link).
 Command to copy:
 $rSection = Copy::copy ($rCfg->GetSection (...));
 
 $rSection - reference to the section-object
 $SectionName - name of the section 
 $Before - the empty section will should be added before this section
           by default the empty section is appended
 
 returnvalue - config-file-object

=item *

 ChangeSectionName($OldName, $NewName)
 This function changes the name of an existing section in the 
 config-file-object.
 
 $OldName - old name of the section
 $NewName - new name of the section
 
 returnvalue - config-file-object

=item *

 SetSectionOrder(@NewSecList)
 This function redefines the order of sections in am cfg-object.
 
 @NewSecList - new array of the sections
 
 returnvalue - 0   O.K.
               > 0 Fehler: The lengh or the content of the new list 
               does not match those of the old one.

=item *

 GetSigns()
 This internal function determines valid characters. 
 
 no parameters
 
 returnvalues: $CommentSign, $SectionTest, $KeyTest, $Valuetest

=item *

 DeleteKey($SectionName, $KeyName)
 This function deletes the selected key from the selected section.
 
 $SectionName - name of the section
 $KeyName - name of the key
 
 returnvalue - reference to the deleted key

=item *

 Append($Value, $Neu)
 This is a support function. It extends a cfg-entry (classical example: 
 PLOTTER_SECTIONS). $Neu is appended to $Value, at which a following line 
 is created. The function tries to preserve the indentation.
 
 $Value - cfg-entry (retrieve via GetValue(..., "ASIS"))
 $Neu - is appended

 returnvalue - the string with the expanded cfg-entry

=item *

 Write($File, $Handle)
 This function writes the cfg-object into the selected file.
 
 $File - name of or handle to the config file
 $Handle - if true, a handle is expected in $File
           false ist default

 returnvalue - cfg-object

=back

=head1 AUTHOR

SEAL Systems

=head1 BUGS

none

=head1 SEE ALSO

no links

=cut
