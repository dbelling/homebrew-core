class Mapserver < Formula
  desc "Publish spatial data and interactive mapping apps to the web"
  homepage "http://mapserver.org/"
  url "https://download.osgeo.org/mapserver/mapserver-7.0.7.tar.gz"
  sha256 "37a8c3008328bae0fea05109d6d544a3284f756a23956e8a2f5ec10a6b5fef67"
  revision 2

  bottle do
    cellar :any
    sha256 "861890728eb6d3fb016b9b820f301da7f79136f454820ef8d3eb1387711f8df3" => :high_sierra
    sha256 "00e9069aba52817cbd8e27ee77113bdfd4f4ac3f0fc6fb89f16b8ae451e53fda" => :sierra
    sha256 "e1c69d346d18201436a8afdbc40e7ef0b0e6ed80ec8ac47eba6ac5e04f65af8e" => :el_capitan
  end

  option "with-fastcgi", "Build with fastcgi support"
  option "with-geos", "Build support for GEOS spatial operations"
  option "with-php", "Build PHP MapScript module"
  option "with-postgresql", "Build support for PostgreSQL as a data source"

  depends_on "pkg-config" => :build
  depends_on "cmake" => :build
  depends_on "swig" => :build
  depends_on "freetype"
  depends_on "libpng"
  depends_on "giflib"
  depends_on "gd"
  depends_on "proj"
  depends_on "gdal"
  depends_on "geos" => :optional
  depends_on "postgresql" => :optional unless MacOS.version >= :lion
  depends_on "cairo" => :optional
  depends_on "fcgi" if build.with? "fastcgi"

  def install
    # Harfbuzz support requires fribidi and fribidi support requires
    # harfbuzz but fribidi currently fails to build with:
    # fribidi-common.h:61:12: fatal error: 'glib.h' file not found
    args = std_cmake_args + %w[
      -DWITH_KML=ON
      -DWITH_CURL=ON
      -DWITH_CLIENT_WMS=ON
      -DWITH_CLIENT_WFS=ON
      -DWITH_SOS=ON
      -DWITH_PROJ=ON
      -DWITH_GDAL=ON
      -DWITH_OGR=ON
      -DWITH_WFS=ON
      -DWITH_FRIBIDI=OFF
      -DWITH_HARFBUZZ=OFF
      -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python
    ]

    # Install within our sandbox.
    inreplace "mapscript/php/CMakeLists.txt", "${PHP5_EXTENSION_DIR}", lib/"php/extensions"
    args << "-DWITH_PHP=ON" if build.with? "php"

    # Install within our sandbox.
    inreplace "mapscript/python/CMakeLists.txt" do |s|
      s.gsub! "${PYTHON_SITE_PACKAGES}", lib/"python2.7/site-packages"
      s.gsub! "${PYTHON_LIBRARIES}", "-Wl,-undefined,dynamic_lookup"
    end
    args << "-DWITH_PYTHON=ON"
    # Using rpath on python module seems to cause problems if you attempt to
    # import it with an interpreter it wasn't built against.
    # 2): Library not loaded: @rpath/libmapserver.1.dylib
    args << "-DCMAKE_SKIP_RPATH=ON"

    # All of the below are on by default so need
    # explicitly disabling if not requested.
    if build.with? "geos"
      args << "-DWITH_GEOS=ON"
    else
      args << "-DWITH_GEOS=OFF"
    end

    if build.with? "cairo"
      args << "-WITH_CAIRO=ON"
    else
      args << "-DWITH_CAIRO=OFF"
    end

    if build.with? "postgresql"
      args << "-DWITH_POSTGIS=ON"
    else
      args << "-DWITH_POSTGIS=OFF"
    end

    if build.with? "fastcgi"
      args << "-DWITH_FCGI=ON"
    else
      args << "-DWITH_FCGI=OFF"
    end

    mkdir "build" do
      system "cmake", "..", *args
      system "make", "install"
    end
  end

  def caveats; <<~EOS
    The Mapserver CGI executable is #{opt_bin}/mapserv

    If you built the PHP option:
      * Add the following line to php.ini:
        extension="#{opt_lib}/php/extensions/php_mapscript.so"
      * Execute "php -m"
      * You should see MapScript in the module list
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mapserv -v")
    system "python2.7", "-c", "import mapscript"
  end
end
