package client

import (
	"fmt"
	"log"
	"math"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/simpleiot/simpleiot/data"
)

// SignalGenerator config
type SignalGenerator struct {
	ID          string  `node:"id"`
	Parent      string  `node:"parent"`
	Description string  `point:"description"`
	Frequency   float64 `point:"frequency"`
	Amplitude   float64 `point:"amplitude"`
	Offset      float64 `point:"offset"`
	SampleRate  float64 `point:"sampleRate"`
	Value       float64 `point:"value"`
	Units       string  `point:"units"`
	HighRate    bool    `point:"highRate"`
	BatchPeriod int     `point:"batchPeriod"`
	Disable     bool    `point:"disable"`
}

// SignalGeneratorClient for signal generator nodes
type SignalGeneratorClient struct {
	nc            *nats.Conn
	config        SignalGenerator
	stop          chan struct{}
	newPoints     chan NewPoints
	newEdgePoints chan NewPoints
	natsSubject   string
}

// NewSignalGeneratorClient ...
func NewSignalGeneratorClient(nc *nats.Conn, config SignalGenerator) Client {
	return &SignalGeneratorClient{
		nc:            nc,
		config:        config,
		stop:          make(chan struct{}),
		newPoints:     make(chan NewPoints),
		newEdgePoints: make(chan NewPoints),
		natsSubject:   fmt.Sprintf("phrup.%v.%v", config.Parent, config.ID),
	}
}

// Run the main logic for this client and blocks until stopped
func (sgc *SignalGeneratorClient) Run() error {
	log.Println("Starting sig gen client: ", sgc.config.Description)

	chStopGen := make(chan struct{})

	generator := func(config SignalGenerator) {
		configValid := true

		if config.Disable {
			log.Printf("Sig Gen %v: disabled\n", config.Description)
			configValid = false
		}
		if config.Frequency <= 0 {
			log.Printf("Sig Gen %v: Frequency must be set\n", config.Description)
			configValid = false
		}

		if config.Amplitude <= 0 {
			log.Printf("Sig Gen %v: Amplitude must be set\n", config.Description)
			configValid = false
		}

		if config.SampleRate <= 0 {
			log.Printf("Sig Gen %v: SampleRate must be set\n", config.Description)
			configValid = false
		}

		if config.HighRate && config.BatchPeriod <= 0 {
			log.Printf("Sig Gen %v: batch must be set for HR data\n", config.Description)
			configValid = false
		}

		if config.HighRate {
			log.Printf("Sig Gen %v: HR data not currently supported\n", config.Description)
			configValid = false
		}

		t := time.NewTicker(time.Hour)
		t.Stop()

		// NOP for now
		sendSample := func(sTime time.Time) {
		}

		if configValid {
			var start time.Time

			natsSubject := SubjectNodePoints(config.ID)

			if config.HighRate {
				natsSubject = fmt.Sprintf("phrup.%v.%v", config.Parent, config.ID)
			}

			// calc period in ns
			periodCount := int(config.SampleRate) / int(config.Frequency)

			increment := (2 * math.Pi / config.SampleRate) * config.Frequency

			count := 0

			sendSample = func(sTime time.Time) {
				value := math.Sin(increment*float64(count)) * config.Amplitude
				count++
				if count >= periodCount {
					count = 0
				}

				p := data.Points{{Time: sTime, Type: data.PointTypeValue,
					Value: value}}

				err := SendPoints(sgc.nc, natsSubject, p, false)
				if err != nil {
					log.Println("Error sending points: ", err)
				}
			}

			t.Reset(time.Duration(1/config.SampleRate*1e9) * time.Nanosecond)
			// get start time
			start = <-t.C
			sendSample(start)
		}

		for {
			select {
			case sTime := <-t.C:
				sendSample(sTime)
			case <-chStopGen:
				return
			}
		}
	}

	go generator(sgc.config)

done:
	for {
		select {
		case <-sgc.stop:
			chStopGen <- struct{}{}
			log.Println("Stopping signal generator client: ", sgc.config.Description)
			break done
		case pts := <-sgc.newPoints:
			err := data.MergePoints(pts.ID, pts.Points, &sgc.config)
			if err != nil {
				log.Println("error merging new points: ", err)
			}

			for _, p := range pts.Points {
				switch p.Type {
				case data.PointTypeFrequency, data.PointTypeAmplitude,
					data.PointTypeOffset, data.PointTypeSampleRate,
					data.PointTypeDisable, data.PointTypeHighRate:
					// restart generator
					chStopGen <- struct{}{}
					go generator(sgc.config)
				}
			}

		case pts := <-sgc.newEdgePoints:
			err := data.MergeEdgePoints(pts.ID, pts.Parent, pts.Points, &sgc.config)
			if err != nil {
				log.Println("error merging new points: ", err)
			}
		}
	}

	// clean up
	return nil
}

// Stop sends a signal to the Run function to exit
func (sgc *SignalGeneratorClient) Stop(_ error) {
	close(sgc.stop)
}

// Points is called by the Manager when new points for this
// node are received.
func (sgc *SignalGeneratorClient) Points(nodeID string, points []data.Point) {
	sgc.newPoints <- NewPoints{nodeID, "", points}
}

// EdgePoints is called by the Manager when new edge points for this
// node are received.
func (sgc *SignalGeneratorClient) EdgePoints(nodeID, parentID string, points []data.Point) {
	sgc.newEdgePoints <- NewPoints{nodeID, parentID, points}
}
