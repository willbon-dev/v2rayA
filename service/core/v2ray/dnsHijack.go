package v2ray

import (
	"fmt"
	"github.com/v2rayA/v2rayA/core/specialMode"
	"github.com/v2rayA/v2rayA/db/configure"
	"os"
	"time"
)

const (
	resolverFile  = "/etc/resolv.conf"
	checkInterval = 3 * time.Second
)

type ResolvHijacker struct {
	ticker      *time.Ticker
	localDNS    bool
	tunModeDNS  bool
	resolverCfg []byte
}

func NewResolvHijacker() *ResolvHijacker {
	setting := configure.GetSettingNotNil()
	tunModeDNS := setting.Transparent != configure.TransparentClose &&
		(setting.TransparentType == configure.TransparentGvisorTun ||
			setting.TransparentType == configure.TransparentSystemTun)
	resolverCfg := []byte(HijackFlag + "\nnameserver 127.2.0.17\nnameserver 119.29.29.29\n")
	if tunModeDNS {
		// In TUN mode on WSL/Docker, system DNS often points to a local stub
		// (for example 10.255.255.254) that never reaches the TUN DNS handler.
		// Point the system resolver at the TUN DNS address directly so FakeIP and
		// DNS routing can actually take effect.
		resolverCfg = []byte(HijackFlag + "\nnameserver 172.19.0.2\nnameserver 223.6.6.6\n")
	}
	hij := ResolvHijacker{
		ticker:      time.NewTicker(checkInterval),
		localDNS:    specialMode.ShouldLocalDnsListen(),
		tunModeDNS:  tunModeDNS,
		resolverCfg: resolverCfg,
	}
	hij.HijackResolv()
	go func() {
		for range hij.ticker.C {
			hij.HijackResolv()
		}
	}()
	return &hij
}
func (h *ResolvHijacker) Close() error {
	h.ticker.Stop()
	return nil
}

const HijackFlag = "# v2rayA DNS hijack"

var hijacker *ResolvHijacker

func (h *ResolvHijacker) HijackResolv() error {
	err := os.WriteFile(resolverFile,
		h.resolverCfg,
		os.FileMode(0644),
	)
	if err != nil {
		err = fmt.Errorf("failed to hijackDNS: [write] %v", err)
	}
	return err
}

func resetResolvHijacker() {
	if hijacker != nil {
		hijacker.Close()
	}
	hijacker = NewResolvHijacker()
}

func removeResolvHijacker() {
	if hijacker != nil {
		hijacker.Close()
		if hijacker.tunModeDNS || hijacker.localDNS {
			os.WriteFile(resolverFile,
				[]byte(HijackFlag+"\nnameserver 223.6.6.6\nnameserver 119.29.29.29\n"),
				os.FileMode(0644),
			)
		}
		hijacker = nil

	}
}
