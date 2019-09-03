package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
)

func main() {
	fmt.Printf("DISABLED_DECODERS_FLAGS=\"%s\"\n", prepare_disabled_codecs_flags(false))
	fmt.Printf("ENABLED_DECODERS_FLAGS=\"%s\"\n", prepare_enabled_decoders_flags())
	fmt.Printf("DISABLED_ENCODERS_FLAGS=\"%s\"\n", prepare_disabled_codecs_flags(true))
}

func prepare_enabled_decoders_flags() string {
	var byte_buffer bytes.Buffer
	enabled_decoders_map := load_enabled_decoders_map()
	for decoder, _ := range enabled_decoders_map {
		byte_buffer.WriteString(fmt.Sprintf("--enable-decoder=%s ", decoder))
	}
	return strings.TrimSpace(byte_buffer.String())
}

// returns either disabled encoders flags or disabled decoders.
// disabled decoders take into consideration the enabled encoders on the enabled-decoders.txt file
func prepare_disabled_codecs_flags(encoders bool) string {
	var byte_buffer bytes.Buffer
	available_codecs_array := load_available_codecs(encoders)
	subject := (map[bool]string{true: "encoder", false: "decoder"})[encoders]
	var enabled_decoders_map map[string]bool // only assigned if we're using decoders
	// If we're talking about decoders to disable, we need to know which decoders
	// have been marked for enablement.
	if !encoders {
		enabled_decoders_map = load_enabled_decoders_map()
	}
	for _, codec := range available_codecs_array {
		if !encoders {
			// we skip if the current encoder is enabled
			_, decoder_enabled := enabled_decoders_map[codec]
			if decoder_enabled {
				//skip enabled decoder when preparing disabled decoders
				continue
			}
		}
		byte_buffer.WriteString(fmt.Sprintf("--disable-%s=%s ", subject, strings.TrimSpace(codec)))
	}
	return strings.TrimSpace(byte_buffer.String())
}

// Loads decoders we specify on the .txt file as enabled.
func load_enabled_decoders_map() map[string]bool {
	file, err := os.Open("enabled-decoders.txt")
	if err != nil {
		panic(err)
	}
	defer file.Close()
	decoders_bytes, err := ioutil.ReadAll(file)
	if err != nil {
		panic(err)
	}
	decoders_arr := strings.Split(string(decoders_bytes), " ")
	result := make(map[string]bool)
	for _, decoder := range decoders_arr {
		result[strings.TrimSpace(decoder)] = true
	}
	return result
}

func load_available_codecs(encoders bool) []string {
	if _, err := os.Stat("mplayer-trunk"); os.IsNotExist(err) {
		panic(err)
	}
	if _, err := os.Stat("mplayer-trunk/ffmpeg"); os.IsNotExist(err) {
		panic(err)
	}
	subject := (map[bool]string{true: "encoders", false: "decoders"})[encoders]
	cmd := exec.Command("./configure", fmt.Sprintf("--list-%s", subject))
	cmd.Dir = "mplayer-trunk/ffmpeg"
	codecs_bytes, err := cmd.Output()
	if err != nil {
		panic(err)
	}
	codecs := strings.Fields(string(codecs_bytes))
	return codecs
}
