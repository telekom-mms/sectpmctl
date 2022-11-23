all: 

install:
	install -d $(DESTDIR)/usr/sbin
	install -m 0755 src/usr/sbin/sectpmctl $(DESTDIR)/usr/sbin
	install -d $(DESTDIR)/usr/share/bash-completion/completions
	install -m 0755 src/usr/share/bash-completion/completions/_sectpmctl $(DESTDIR)/usr/share/bash-completion/completions
	install -d $(DESTDIR)/usr/lib/sectpmctl
	install -m 0755 src/usr/lib/sectpmctl/boot.conf $(DESTDIR)/usr/lib/sectpmctl
	install -d $(DESTDIR)/usr/lib/sectpmctl/keys
	install -m 0644 src/usr/lib/sectpmctl/keys/canonical-master-public.pem $(DESTDIR)/usr/lib/sectpmctl/keys
	install -m 0644 src/usr/lib/sectpmctl/keys/dbxupdate_x64.bin $(DESTDIR)/usr/lib/sectpmctl/keys
	install -m 0644 src/usr/lib/sectpmctl/keys/MicCorUEFCA2011_2011-06-27.crt $(DESTDIR)/usr/lib/sectpmctl/keys
	install -m 0644 src/usr/lib/sectpmctl/keys/MicWinProPCA2011_2011-10-19.crt $(DESTDIR)/usr/lib/sectpmctl/keys
	install -d $(DESTDIR)/usr/lib/sectpmctl/scripts
	install -m 0755 src/usr/lib/sectpmctl/scripts/dkms_sign_helper.sh $(DESTDIR)/usr/lib/sectpmctl/scripts
	install -m 0755 src/usr/lib/sectpmctl/scripts/kmodsign_obj.sh $(DESTDIR)/usr/lib/sectpmctl/scripts
	ln -s /usr/lib/sectpmctl/scripts/kmodsign_obj.sh $(DESTDIR)/usr/lib/sectpmctl/scripts/kmodsign.sh
	install -m 0755 src/usr/lib/sectpmctl/scripts/sbsign_obj.sh $(DESTDIR)/usr/lib/sectpmctl/scripts
	ln -s /usr/lib/sectpmctl/scripts/sbsign_obj.sh $(DESTDIR)/usr/lib/sectpmctl/scripts/sbsign.sh
	install -m 0755 src/usr/lib/sectpmctl/scripts/sectpmctl-boot $(DESTDIR)/usr/lib/sectpmctl/scripts
	install -m 0755 src/usr/lib/sectpmctl/scripts/sectpmctl-key $(DESTDIR)/usr/lib/sectpmctl/scripts
	install -m 0755 src/usr/lib/sectpmctl/scripts/sectpmctl-tpm $(DESTDIR)/usr/lib/sectpmctl/scripts
	install -d $(DESTDIR)/usr/share/sectpmctl
	install -m 0644 LICENSE $(DESTDIR)/usr/share/sectpmctl/LICENSE
	install -m 0644 README.md $(DESTDIR)/usr/share/sectpmctl/README.md
	install -d $(DESTDIR)/etc/sectpmctl
	install -d $(DESTDIR)/etc/kernel/postinst.d
	install -m 0755 src/etc/kernel/postinst.d/zz-update-sectpmctl-boot $(DESTDIR)/etc/kernel/postinst.d
	install -d $(DESTDIR)/etc/kernel/postrm.d
	ln -s ../postinst.d/zz-update-sectpmctl-boot $(DESTDIR)/etc/kernel/postrm.d/zz-update-sectpmctl-boot
	install -d $(DESTDIR)/etc/initramfs/post-update.d
	ln -s ../../kernel/postinst.d/zz-update-sectpmctl-boot $(DESTDIR)/etc/initramfs/post-update.d/zz-update-sectpmctl-boot

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
	tar cvzf "$${DIR}_1.1.2.orig.tar.gz" "$$DIR"
