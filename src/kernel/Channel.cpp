#include <cstring>
#include <cmath>
#include <iostream>

#include <kernel/Channel.hpp>
#include <kernel/Memory.hpp>

#include <devices/Audio.hpp>

using namespace std;

Channel::Channel(Memory &memory):
                reverb_position(0),
                memory(*((MemoryLayout*)memory.allocate(sizeof(MemoryLayout), "FM Audio Channel"))) {
    buffer = new int16_t[AUDIO_DELAY_SIZE*2];
    samples = new int16_t[AUDIO_SAMPLE_AMOUNT*2];

    memset(buffer, 0, AUDIO_DELAY_MEM_SIZE);
}

Channel::~Channel() {
    delete buffer;
    delete samples;
}

void Channel::fill(int16_t* output, const unsigned int sample_count) {
    memset(samples, 0, sample_count*sizeof(int16_t));

    for (auto it=synthesizers.cbegin(); it != synthesizers.cend();) {
        if (it->second->done()) {
            synthesizers.erase(it++);
        } else {
            it->second->fill(output, samples, sample_count);
            it++;
        }
    }

    reverb(output, samples, sample_count);
}

void Channel::reverb(int16_t *output, int16_t *in, const unsigned int length) {
    int reverb_distance = max(min(AUDIO_DELAY_AMOUNT, int(memory.delay.delay)), 1)*AUDIO_DELAY_LENGTH;

    for (int i=0;i<int(length);i++) {
        int reverb_sample = reverb_position-reverb_distance;

        if (reverb_sample < 0) {
            reverb_sample += AUDIO_DELAY_SIZE;
        }

        int delta = buffer[reverb_sample]*Audio::tof16(memory.delay.feedback);
        int out;

        out = delta+output[i];

        if (out < INT16_MIN) {
            out = INT16_MIN;
        } else if (out > INT16_MAX) {
            out = INT16_MAX;
        }

        output[i] = out;

        out = in[i]+delta;

        if (out < INT16_MIN) {
            out = INT16_MIN;
        } else if (out > INT16_MAX) {
            out = INT16_MAX;
        }

        buffer[reverb_position] = out;

        reverb_position += 1;

        if (reverb_position >= int(AUDIO_DELAY_SIZE)) {
            reverb_position = 0;
        }
    }
}

void Channel::press(uint8_t note, uint8_t intensity) {
    if (synthesizers.find(note) == synthesizers.end()) {
        synthesizers.emplace(note, make_unique<FMSynthesizer>(memory.synthesizer, note));
        synthesizers[note]->on(intensity);
    } else {
        synthesizers[note]->on(intensity);
    }
}

void Channel::release(uint8_t note) {
    if (synthesizers.find(note) != synthesizers.end()) {
        synthesizers[note]->off();
    }
}

void Channel::enqueue_command(uint64_t timestamp,
                              uint8_t command,
                              uint8_t note,
                              uint8_t velocity) {
    commands.push(Command {
        timestamp,
        (Cmd)command,
        note,
        velocity,
    });
}

void Channel::execute_commands(const uint64_t t) {
    while (!commands.empty() && commands.front().timestamp <= t) {
        const auto command = commands.front();

        switch (command.cmd) {
            case NoteOn:
                press(command.note, command.intensity);
                break;
            case NoteOff:
                release(command.note);
                break;
        }

        commands.pop();
    }
}
