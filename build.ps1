# diffpy-cmi build script for windows

$pipOption="" # e.g. --proxy=http://username:password@url:port
$rootDir=Get-Location

$buildBoost=1
$boostVersionDot="1.81.0"
$boostVersionUnderscore="1_81_0"
$boostDirName="boost_$($boostVersionUnderscore)"
$boostSourceZipUrl="https://sourceforge.net/projects/boost/files/boost/$($boostVersionDot)/$($boostDirName).zip"

# not sure for scons output dir path.
# maybe need to change this.
$sconsBuildDir="build\fast-AMD64"

if ($buildBoost) {
    Write-Output "Installing boost..."
    if (-Not(Test-Path "$($boostDirName).zip")) {
        Invoke-WebRequest -Uri $boostSourceZipUrl -OutFile "$($boostDirName).zip" -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
    }
    if (-Not(Test-Path $boostDirName)) {
        # default unzip command is very slow...
        #Expand-Archive -Path "$($boostDirName).zip" -DestinationPath .
        Add-Type -Assembly "System.IO.Compression.Filesystem"
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$($rootDir)\$($boostDirName).zip", "$($rootDir)\.")
    }

    Set-Location $boostDirName
    if (-Not(Test-Path .\b2.exe)) {
        .\bootstrap.bat
    }
    # TODO static build gives different name?
    .\b2.exe --prefix=. `
        --layout=system --with-serialization `
        link=shared threading=multi variant=release address-model=64 runtime-link=shared
    Copy-Item -Path ".\stage\lib\libboost_serialization.lib" -Destination ".\stage\lib\boost_serialization.lib"
    Set-Location $rootDir
    $boostIncludePath="$($rootDir)\$($boostDirName)\"
    Write-Output "Adding $($boostIncludePath) to env:INCLUDE..."
    #addEnvironmentVariable($env:INCLUDE, $boostIncludePath)
    if (-Not( $env:INCLUDE -split ";" -contains $boostIncludePath )) {
        $env:INCLUDE+=";$($boostIncludePath)"
    }
    
    $boostLibPath="$($rootDir)\$($boostDirName)\stage\lib\"
    Write-Output "Adding $($boostLibPath) to env:LIB..."
    #addEnvironmentVariable($env:LIB, $boostLibPath)
    if (-Not( $env:LIB-split ";" -contains $boostLibPath )) {
        $env:LIB+=";$($boostLibPath)"
    }
}

Write-Output "Installing scons..."
pip install scons $pipOption

Write-Output "Installing libobjcryst..."
git clone https://github.com/diffpy/libobjcryst.git
Copy-Item -Path ".\libobjcryst_SConstruct" -Destination ".\libobjcryst\SConstruct"
Copy-Item -Path ".\libobjcryst_src_SConscript" -Destination ".\libobjcryst\src\SConscript"
Set-Location .\libobjcryst
$env:PREFIX="."
#scons -j8 build
#Move-Item ".\build\fast-AMD64\libObjCryst.lib" ".\build\fast-AMD64\ObjCryst.lib"
scons -j8 install
Set-Location $rootDir
$libobjcrystIncludePath="$($rootDir)\libobjcryst\$($sconsBuildDir)\"
if (-Not( $env:INCLUDE -split ";" -contains $libobjcrystIncludePath )) {
    $env:INCLUDE+=";$($libobjcrystIncludePath)"
}
$libobjcrystLibraryPath="$($rootDir)\libobjcryst\$($sconsBuildDir)\"
if (-Not( $env:LIB-split ";" -contains $libobjcrystLibraryPath )) {
    $env:LIB+=";$($libobjcrystLibraryPath)"
}

Write-Output "Installing GSL..."
git clone https://github.com/ampl/gsl.git
mkdir -Force .\gsl\build
Set-Location .\gsl\build
cmake -G "NMake Makefiles" -S .. -B . `
    -DNO_AMPL_BINDINGS=1 -DGSL_DISABLE_TEST=1 -DDOCUMENTATION=OFF
nmake
Set-Location $rootDir
$gslIncludePath="$($rootDir)\gsl\build\"
if (-Not( $env:INCLUDE -split ";" -contains $gslIncludePath )) {
    $env:INCLUDE+=";$($gslIncludePath)"
}
$gslLibraryPath="$($rootDir)\gsl\build\"
if (-Not( $env:LIB-split ";" -contains $gslLibraryPath )) {
    $env:LIB+=";$($gslLibraryPath)"
}

Write-Output "Installing Dlfcn..."
git clone https://github.com/dlfcn-win32/dlfcn-win32.git
mkdir -Force .\dlfcn-win32\build
Set-Location .\dlfcn-win32\build
cmake -G "NMake Makefiles" -S .. -B . -DBUILD_SHARED_LIBS=OFF `
    -DCMAKE_INSTALL_PREFIX="."
nmake install
Set-Location $rootDir
$dlfcnIncludePath="$($rootDir)\dlfcn-win32\build\include\"
if (-Not( $env:INCLUDE -split ";" -contains $dlfcnIncludePath )) {
    $env:INCLUDE+=";$($dlfcnIncludePath)"
}
$dlfcnLibraryPath="$($rootDir)\dlfcn-win32\build\lib\"
if (-Not( $env:LIB-split ";" -contains $dlfcnLibraryPath )) {
    $env:LIB+=";$($dlfcnLibraryPath)"
}

Write-Output "Building libdiffpy..."
git clone https://github.com/diffpy/libdiffpy.git
Write-Output "Applying custom SConstruct..."
Copy-Item .\libdiffpy_SConstruct libdiffpy/SConstruct
Copy-Item .\libdiffpy_src_SConscript.configure .\libdiffpy\src\SConscript.configure
Copy-Item .\libdiffpy_src_SConscript .\libdiffpy\src\SConscript
Copy-Item .\libdiffpy_src_diffpy_srreal_StructureAdapter.hpp .\libdiffpy\src\diffpy\srreal\StructureAdapter.hpp
Copy-Item .\libdiffpy_src_diffpy_mathutils.hpp .\libdiffpy\src\diffpy\mathutils.hpp
Copy-Item .\libdiffpy_src_diffpy_mathutils.ipp .\libdiffpy\src\diffpy\mathutils.ipp
Copy-Item .\libdiffpy_src_diffpy_runtimepath.cpp .\libdiffpy\src\diffpy\runtimepath.cpp
Copy-Item .\libdiffpy_src_diffpy_srreal_scatteringfactordata.cpp .\libdiffpy\src\diffpy\srreal\scatteringfactordata.cpp

Set-Location ./libdiffpy
scons -j8 install

$libdiffpyIncludePath="$($rootDir)\libdiffpy\$($sconsBuildDir)\include\"
if (-Not($env:INCLUDE -contains $libdiffpyIncludePath)) {
    $env:INCLUDE+=";$($libdiffpyIncludePath)"
}
$libdiffpyLibraryPath="$($rootDir)\libdiffpy\$($sconsBuildDir)\lib\"
if (-Not($env:LIB -contains $libdiffpyLibraryPath)) {
    $env:LIB+=";$($libdiffpyLibraryPath)"
}

Set-Location examples

cl.exe /EHsc /DBOOST_ALL_NO_LIB /MT /O2 testlib.cpp diffpy.lib boost_serialization.lib
.\testlib.exe

Set-Location $rootDir