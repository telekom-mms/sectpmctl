all: 

install:
	install -d $(DESTDIR)/usr/bin
	install -m 0755 src/usr/bin/mmstpm2-boot $(DESTDIR)/usr/bin
	install -d $(DESTDIR)/usr/sbin
	install -m 0755 src/usr/sbin/mmstpm2 $(DESTDIR)/usr/sbin
	install -d $(DESTDIR)/usr/share/mmstpm2
	install -m 0644 src/usr/share/mmstpm2/boot.conf $(DESTDIR)/usr/share/mmstpm2
	install -m 0755 src/usr/share/mmstpm2/dkms_sign_helper.sh $(DESTDIR)/usr/share/mmstpm2
	install -m 0755 src/usr/share/mmstpm2/kmodsign.sh $(DESTDIR)/usr/share/mmstpm2
	install -m 0755 src/usr/share/mmstpm2/sbsign.sh $(DESTDIR)/usr/share/mmstpm2
	install -m 0700 -d $(DESTDIR)/etc/mmstpm2/keys
	install -m 0644 src/etc/mmstpm2/keys/canonical-master-public.pem $(DESTDIR)/etc/mmstpm2/keys
	install -m 0644 src/etc/mmstpm2/keys/dbxupdate_x64.bin $(DESTDIR)/etc/mmstpm2/keys
	install -m 0644 src/etc/mmstpm2/keys/MicCorUEFCA2011_2011-06-27.crt $(DESTDIR)/etc/mmstpm2/keys
	install -m 0644 src/etc/mmstpm2/keys/MicWinProPCA2011_2011-10-19.crt $(DESTDIR)/etc/mmstpm2/keys
	install -d $(DESTDIR)/etc/kernel/postinst.d
	install -m 0755 src/etc/kernel/postinst.d/zz-update-mmstpm2-boot $(DESTDIR)/etc/kernel/postinst.d
	install -d $(DESTDIR)/etc/kernel/postrm.d
	ln -s ../postinst.d/zz-update-mmstpm2-boot $(DESTDIR)/etc/kernel/postrm.d/zz-update-mmstpm2-boot
	install -d $(DESTDIR)/etc/initramfs/post-update.d
	ln -s ../../kernel/postinst.d/zz-update-mmstpm2-boot $(DESTDIR)/etc/initramfs/post-update.d/zz-update-mmstpm2-boot

package_build: package_clean package_dist
	debuild -i

package_clean:
	-rm -Rf debian/.debhelper
	-rm -Rf debian/$(firstword $(subst _, ,$(lastword $(subst /, ,$(shell pwd)))))*
	-rm debian/debhelper-build-stamp debian/files
	-rm ../$(lastword $(subst /, ,$(shell pwd)))?*

package_dist:
	cd .. && \
	DIR=$(lastword $(subst /, ,$(shell pwd))) && \
	tar cvzf "$${DIR}_1.0.0.orig.tar.gz" "$$DIR"
