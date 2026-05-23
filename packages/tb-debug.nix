{ writeShellScriptBin }:

writeShellScriptBin "tb-debug" ''
  set -e
  CONTROL="/proc/dynamic_debug/control"

  case "''${1:-status}" in
    on|enable)
      echo "Enabling PCI/Thunderbolt debug output..."
      echo "file drivers/pci/pci.c +p" | sudo tee $CONTROL > /dev/null
      echo "file drivers/pci/pcie/aspm.c +p" | sudo tee $CONTROL > /dev/null
      echo "module thunderbolt +p" | sudo tee $CONTROL > /dev/null
      echo "file pciehp* +p" | sudo tee $CONTROL > /dev/null
      echo "Debug enabled. Use 'journalctl -kf' to watch output."
      ;;
    off|disable)
      echo "Disabling PCI/Thunderbolt debug output..."
      echo "file drivers/pci/pci.c -p" | sudo tee $CONTROL > /dev/null
      echo "file drivers/pci/pcie/aspm.c -p" | sudo tee $CONTROL > /dev/null
      echo "module thunderbolt -p" | sudo tee $CONTROL > /dev/null
      echo "file pciehp* -p" | sudo tee $CONTROL > /dev/null
      echo "Debug disabled."
      ;;
    status)
      echo "Currently enabled debug points:"
      grep "=p" $CONTROL | grep -E "(pci|thunderbolt|pciehp)" || echo "  (none)"
      ;;
    trace-on)
      echo "Enabling Thunderbolt tracepoints..."
      sudo mount -t tracefs tracefs /sys/kernel/debug/tracing 2>/dev/null || true
      echo 1 | sudo tee /sys/kernel/debug/tracing/events/thunderbolt/enable > /dev/null
      echo "Tracepoints enabled. View with: cat /sys/kernel/debug/tracing/trace"
      ;;
    trace-off)
      echo "Disabling Thunderbolt tracepoints..."
      echo 0 | sudo tee /sys/kernel/debug/tracing/events/thunderbolt/enable > /dev/null
      echo "Tracepoints disabled."
      ;;
    trace)
      cat /sys/kernel/debug/tracing/trace
      ;;
    *)
      echo "Usage: tb-debug [on|off|status|trace-on|trace-off|trace]"
      echo ""
      echo "Commands:"
      echo "  on        Enable dyndbg for PCI/Thunderbolt"
      echo "  off       Disable dyndbg for PCI/Thunderbolt"
      echo "  status    Show currently enabled debug points"
      echo "  trace-on  Enable Thunderbolt tracepoints"
      echo "  trace-off Disable Thunderbolt tracepoints"
      echo "  trace     View trace output"
      exit 1
      ;;
  esac
''
