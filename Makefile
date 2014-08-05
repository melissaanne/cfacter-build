solaris_version=2.10
binutils_ver=2.23.2
gcc_ver=4.8.2
cmake_ver=3.0.0
arch=i386

sourceurl=http://enterprise.delivery.puppetlabs.net/sources/solaris

include Makefile.$(arch)

myprojects=binutils gcc cmake
myversions=$(binutils_ver) $(gcc_ver) $(cmake_ver)

projects=$(join $(addsuffix -,$(myprojects)),$(myversions))
builds=$(addprefix build/$(arch)/,$(projects))
source=$(addprefix source/,$(projects))

mydirs=build/$(arch) source $(builds)

make_=$(addsuffix /._.make,$(builds))
get_=$(addsuffix .tar.gz,$(addprefix source/,$(projects)))
patch_=$(addsuffix /._.patch,$(builds))
config_=$(addsuffix /._.config,$(builds))
checkout_=$(addsuffix /._.checkout,$(builds))

ar=/usr/ccs/bin/ar
tar=/usr/sfw/bin/gtar
gzip=/bin/gzip
patch=/bin/gpatch

as=$(prefix)/$(target)/bin/as
ld=$(prefix)/$(target)/bin/ld

export PATH:=$(prefix)/$(target)/bin:/opt/gcc-$(arch)/bin:/usr/ccs/bin:/usr/gnu/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/sfw/bin:/usr/perl5/5.8.4/bin

.PRECIOUS: $(make_) $(get_) $(patch_) $(config_) $(checkout_)

$(mydirs): ; mkdir -p $@

all: build/$(arch)/cmake-$(cmake_ver)/._.install
	@echo $* done

source/%.tar.gz: | source
	wget -q -c -P source/ $(sourceurl)/$*.tar.gz

source/%/._.checkout: | source/%.tar.gz build/$(arch)
	cat source/$*.tar.gz | (cd source/ && $(gzip) -dc | $(tar) -xpf - )
	touch $@

source/binutils-$(binutils_ver)/._.patch: | source/binutils-$(binutils_ver)/._.checkout
	wget -q -c -P source/ $(sourceurl)/patches/binutils-2.23.2-common.h.patch
	wget -q -c -P source/ $(sourceurl)/patches/binutils-2.23.2-ldlang.c.patch
	cat source/binutils-2.23.2-common.h.patch | (cd source/binutils-$(binutils_ver)/include/elf && $(patch) -p0)
	cat source/binutils-2.23.2-ldlang.c.patch | (cd source/binutils-$(binutils_ver)/ && $(patch) -p0)
	touch $@

source/gcc-$(gcc_ver)/._.patch: |  source/gcc-$(gcc_ver)/._.checkout
	wget -q -c -P source/ $(sourceurl)/patches/gcc-contrib-4.8.3.patch
	cat source/gcc-contrib-4.8.3.patch | (cd ./source/gcc-$(gcc_ver) && $(patch) -p1 )
	cd ./source/gcc-$(gcc_ver) && ./contrib/download_prerequisites 2>&1 | cat > .x.patch.log
	touch $@


build/$(arch)/binutils-$(binutils_ver)/._.config: | source/binutils-$(binutils_ver)/._.patch ./build/$(arch)/binutils-$(binutils_ver)
	cd ./build/$(arch)/binutils-$(binutils_ver) && \
		../../../source/binutils-$(binutils_ver)/configure \
			--target=$(target) --prefix=$(prefix) $(sysroot) --disable-nls -v > .x.config.log
	touch $@

build/$(arch)/gcc-$(gcc_ver)/._.config: build/$(arch)/binutils-$(binutils_ver)/._.install

build/$(arch)/gcc-$(gcc_ver)/._.config: | source/gcc-$(gcc_ver)/._.patch ./build/$(arch)/gcc-$(gcc_ver)
	cd ./build/$(arch)/gcc-$(gcc_ver) && \
		../../../source/gcc-$(gcc_ver)/configure \
			--target=$(target) --prefix=$(prefix) $(sysroot) --disable-nls --enable-languages=c,c++ \
			--disable-libgcj \
			--with-gnu-as --with-as=$(as) --with-gnu-ld --with-ld=$(ld) \
			-v > .x.config.log
	touch $@

build/$(arch)/cmake-$(cmake_ver)/._.config: build/$(arch)/gcc-$(gcc_ver)/._.install

build/$(arch)/cmake-$(cmake_ver)/._.config: | source/cmake-$(cmake_ver)/._.patch ./build/$(arch)/cmake-$(cmake_ver)
	cd ./build/$(arch)/cmake-$(cmake_ver) && \
		env CC=$(prefix)/bin/$(i386_TARGET)-gcc CXX=$(prefix)/bin/$(i386_TARGET)-g++" MAKE=$(MAKE) CFLAGS="-I$(prefix)/include" LDFLAGS="-L$(prefix)/lib -R$(prefix)/lib" \
			../../../source/cmake-$(cmake_ver)/bootstrap --prefix=$(prefix) --datadir=/share/cmake --docdir=/share/doc/cmake-$(cmake_ver) --mandir=/share/man --verbose > .x.config.log
	touch $@

source/%/._.patch: | source/%/._.checkout
	touch $@

build/$(arch)/%/._.config: | source/%/._.patch
	touch $@

build/$(arch)/%/._.make: | build/$(arch)/%/._.config
	cd build/$(arch)/$*/ && $(MAKE) > .x.make.log
	touch $@

build/$(arch)/%/._.install: | build/$(arch)/%/._.make
	cd build/$(arch)/$*/ && $(MAKE) install > .x.install.log
	touch $@

clean:
	rm -rf build/$(arch)

# slightly dangerous

# clobber:
#  	[ ! -z $(prefix) ] && rm -rf $(prefix)


prepare:
	rm -rf /opt/gcc-sparc /opt/gcc-i386
	mkdir -p /opt/gcc-sparc /opt/gcc-i386
	chmod 777 /opt/gcc-sparc /opt/gcc-i386


