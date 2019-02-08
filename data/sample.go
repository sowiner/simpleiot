package data

import "time"

// Sample represents a value in time
type Sample struct {
	// Type of sample (voltage, current, key, etc)
	Type string `json:"type,omitempty"`

	// ID of the device that provided the sample
	ID string `json:"id,omitempty"`

	// Analog or digital value of the sample. 0 and 1 are used
	// to represent digital values
	Value float64 `json:"value,omitempty"`

	// Time the sample was taken
	Time time.Time `json:"time,omitempty"`

	// Duration over which the sample was taken
	Duration time.Duration `json:"duration,omitempty"`

	// Tags are additional attributes used to describe the sample
	Tags map[string]string `json:"tags,omitempty"`
}

// NewSample creates a new sample at current time
func NewSample(ID string, value float64) Sample {
	return Sample{
		ID:    ID,
		Value: value,
		Time:  time.Now(),
	}
}
