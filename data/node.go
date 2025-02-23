package data

import (
	"errors"
	"fmt"
	"time"

	"github.com/simpleiot/simpleiot/internal/pb"
	"google.golang.org/protobuf/proto"
)

// SwUpdateState represents the state of an update
type SwUpdateState struct {
	Running     bool   `json:"running"`
	Error       string `json:"error"`
	PercentDone int    `json:"percentDone"`
}

// Points converts SW update state to node points
func (sws *SwUpdateState) Points() Points {
	running := 0.0
	if sws.Running {
		running = 1
	}

	return Points{
		Point{
			Type:  PointTypeSwUpdateRunning,
			Value: running,
		},
		Point{
			Type: PointTypeSwUpdateError,
			Text: sws.Error,
		},
		Point{
			Type:  PointTypeSwUpdatePercComplete,
			Value: float64(sws.PercentDone),
		}}
}

// TODO move Node to db/store package and make it internal to that package

// Node represents the state of a device. UUID is recommended
// for ID to prevent collisions is distributed instances.
type Node struct {
	ID     string `json:"id" boltholdKey:"ID"`
	Type   string `json:"type"`
	Points Points `json:"points"`
}

func (n Node) String() string {
	ret := fmt.Sprintf("NODE: %v (%v)\n", n.ID, n.Type)

	for _, p := range n.Points {
		ret += fmt.Sprintf("  - Point: %v\n", p)
	}

	return ret
}

// Desc returns Description if set, otherwise ID
func (n *Node) Desc() string {
	desc := n.Points.Desc()

	if desc != "" {
		return desc
	}

	return n.ID
}

// FIXME all of the below functions need to be modified to go through NATS
// perhaps they should be removed

// GetState checks state of node and
// returns true if state was updated. We originally considered
// offline to be when we did not receive data from a remote device
// for X minutes. However, with points that could represent a config
// change as well. Eventually we may want to improve this to look
// at point types (perhaps Sample).
func (n *Node) GetState() (string, bool) {
	sysState := n.State()
	switch sysState {
	case PointValueSysStateUnknown, PointValueSysStateOnline:
		if time.Since(n.Points.LatestTime()) > 15*time.Minute {
			// mark device as offline
			return PointValueSysStateOffline, true
		}
	}

	return sysState, false
}

// State returns the current state of a device
func (n *Node) State() string {
	s, _ := n.Points.Text(PointTypeSysState, "")
	return s
}

// ToUser converts a node to user struct
func (n *Node) ToUser() User {
	first, _ := n.Points.Text(PointTypeFirstName, "")
	last, _ := n.Points.Text(PointTypeLastName, "")
	phone, _ := n.Points.Text(PointTypePhone, "")
	email, _ := n.Points.Text(PointTypeEmail, "")
	pass, _ := n.Points.Text(PointTypePass, "")

	return User{
		ID:        n.ID,
		FirstName: first,
		LastName:  last,
		Phone:     phone,
		Email:     email,
		Pass:      pass,
	}
}

// ToNodeEdge converts to data structure used in API
// requests
func (n *Node) ToNodeEdge(edge Edge) NodeEdge {
	return NodeEdge{
		ID:         n.ID,
		Type:       n.Type,
		Parent:     edge.Up,
		Points:     n.Points,
		EdgePoints: edge.Points,
		Hash:       edge.Hash,
	}
}

// Nodes defines a list of nodes
type Nodes []NodeEdge

// ToPb converts a list of nodes to protobuf
func (nodes *Nodes) ToPb() ([]byte, error) {
	pbNodes := make([]*pb.Node, len(*nodes))
	for i, n := range *nodes {
		nPb, err := n.ToPbNode()
		if err != nil {
			return nil, err
		}

		pbNodes[i] = nPb
	}

	return proto.Marshal(&pb.Nodes{Nodes: pbNodes})
}

// ToPbNodes converts a list of nodes to protobuf nodes
func (nodes *Nodes) ToPbNodes() ([]*pb.Node, error) {
	pbNodes := make([]*pb.Node, len(*nodes))
	for i, n := range *nodes {
		nPb, err := n.ToPbNode()
		if err != nil {
			return nil, err
		}

		pbNodes[i] = nPb
	}

	return pbNodes, nil
}

// define valid commands
const (
	CmdUpdateApp = "updateApp"
	CmdPoll      = "poll"
	CmdFieldMode = "fieldMode"
)

// NodeCmd represents a command to be sent to a device
type NodeCmd struct {
	ID     string `json:"id,omitempty" boltholdKey:"ID"`
	Cmd    string `json:"cmd"`
	Detail string `json:"detail,omitempty"`
}

// NodeVersion represents the device SW version
type NodeVersion struct {
	OS  string `json:"os"`
	App string `json:"app"`
	HW  string `json:"hw"`
}

// FIXME -- seems like we could eventually get rid of node edge if we
// do recursion in the client instead of the server. Then the client
// could keep track of the parents and edges in tree data structures
// on the client.

// NodeEdge combines node and edge data, used for APIs
type NodeEdge struct {
	ID         string `json:"id" boltholdKey:"ID"`
	Type       string `json:"type"`
	Hash       uint32 `json:"hash"`
	Parent     string `json:"parent"`
	Points     Points `json:"points"`
	EdgePoints Points `json:"edgePoints"`
}

func (n NodeEdge) String() string {
	ret := fmt.Sprintf("NODE: %v (%v)\n", n.ID, n.Type)
	ret += fmt.Sprintf("  - Parent: %v\n", n.Parent)
	ret += fmt.Sprintf("  - Hash: 0x%x\n", n.Hash)

	for _, p := range n.Points {
		ret += fmt.Sprintf("  - Point: %v\n", p)
	}

	for _, p := range n.EdgePoints {
		ret += fmt.Sprintf("  - Edge point: %v\n", p)
	}

	return ret
}

// IsTombstone returns Tombstone value and timestamp
func (n NodeEdge) IsTombstone() (bool, time.Time) {
	p, _ := n.EdgePoints.Find(PointTypeTombstone, "")
	return p.Bool(), p.Time
}

// Desc returns Description if set, otherwise ID
func (n NodeEdge) Desc() string {
	desc := n.Points.Desc()

	if desc != "" {
		return desc
	}

	return n.ID
}

// CalcHash calculates the hash for a node
func (n NodeEdge) CalcHash(children []NodeEdge) uint32 {
	var ret uint32
	for _, p := range n.Points {
		ret ^= p.CRC()
	}

	for _, p := range n.EdgePoints {
		ret ^= p.CRC()
	}

	for _, c := range children {
		ret ^= c.Hash
	}

	return ret
}

// FIXME -- should ToNode really be used as it is lossy?

// ToNode converts to structure stored in db
func (n *NodeEdge) ToNode() Node {
	return Node{
		ID:     n.ID,
		Type:   n.Type,
		Points: n.Points,
	}
}

// ToPb encodes a node to a protobuf
func (n *NodeEdge) ToPb() ([]byte, error) {

	pbNode, err := n.ToPbNode()
	if err != nil {
		return nil, err
	}

	return proto.Marshal(pbNode)
}

// ToPbNode converts a node to pb.Node type
func (n *NodeEdge) ToPbNode() (*pb.Node, error) {
	points := make([]*pb.Point, len(n.Points))
	edgePoints := make([]*pb.Point, len(n.EdgePoints))

	for i, p := range n.Points {
		pPb, err := p.ToPb()
		if err != nil {
			return &pb.Node{}, err
		}

		points[i] = &pPb
	}

	for i, p := range n.EdgePoints {
		pPb, err := p.ToPb()
		if err != nil {
			return &pb.Node{}, err
		}

		edgePoints[i] = &pPb
	}

	pbNode := &pb.Node{
		Id:         n.ID,
		Type:       n.Type,
		Hash:       int32(n.Hash),
		Points:     points,
		EdgePoints: edgePoints,
		Parent:     n.Parent,
	}

	return pbNode, nil
}

// AddPoint takes a point for a device and adds/updates its array of points
func (n *NodeEdge) AddPoint(pIn Point) {
	n.Points.Add(pIn)
}

// PbDecodeNode converts a protobuf to node data structure
func PbDecodeNode(data []byte) (NodeEdge, error) {
	pbNode := &pb.Node{}

	err := proto.Unmarshal(data, pbNode)
	if err != nil {
		return NodeEdge{}, err
	}

	return PbToNode(pbNode)
}

// PbDecodeNodeRequest converts a protobuf to node data structure
func PbDecodeNodeRequest(buf []byte) (NodeEdge, error) {
	pbNodeRequest := &pb.NodeRequest{}

	err := proto.Unmarshal(buf, pbNodeRequest)
	if err != nil {
		return NodeEdge{}, err
	}

	if pbNodeRequest.Error != "" {
		// error compares fail if they are not the exact same
		// error, even if they have the same text, so compare
		// actual error string here
		if pbNodeRequest.Error == ErrDocumentNotFound.Error() {
			return NodeEdge{}, ErrDocumentNotFound
		}

		return NodeEdge{}, errors.New(pbNodeRequest.Error)
	}

	return PbToNode(pbNodeRequest.Node)
}

// PbToNode converts pb node to node
func PbToNode(pbNode *pb.Node) (NodeEdge, error) {

	points := make([]Point, len(pbNode.Points))
	edgePoints := make([]Point, len(pbNode.EdgePoints))

	for i, pPb := range pbNode.Points {
		s, err := PbToPoint(pPb)
		if err != nil {
			return NodeEdge{}, err
		}
		points[i] = s
	}

	for i, pPb := range pbNode.EdgePoints {
		s, err := PbToPoint(pPb)
		if err != nil {
			return NodeEdge{}, err
		}
		edgePoints[i] = s
	}

	ret := NodeEdge{
		ID:         pbNode.Id,
		Type:       pbNode.Type,
		Hash:       uint32(pbNode.Hash),
		Points:     points,
		EdgePoints: edgePoints,
		Parent:     pbNode.Parent,
	}

	return ret, nil
}

// PbDecodeNodes decode probuf encoded nodes
func PbDecodeNodes(data []byte) ([]NodeEdge, error) {
	pbNodes := &pb.Nodes{}
	err := proto.Unmarshal(data, pbNodes)
	if err != nil {
		return nil, err
	}

	ret := make([]NodeEdge, len(pbNodes.Nodes))

	for i, nPb := range pbNodes.Nodes {
		ret[i], err = PbToNode(nPb)

		if err != nil {
			return ret, err
		}
	}

	return ret, nil
}

// PbDecodeNodesRequest decode probuf encoded nodes
func PbDecodeNodesRequest(data []byte) ([]NodeEdge, error) {
	pbNodesRequest := &pb.NodesRequest{}
	err := proto.Unmarshal(data, pbNodesRequest)
	if err != nil {
		return nil, err
	}

	if pbNodesRequest.Error != "" {
		// error compares fail if they are not the exact same
		// error, even if they have the same text, so compare
		// actual error string here
		if pbNodesRequest.Error == ErrDocumentNotFound.Error() {
			return []NodeEdge{}, ErrDocumentNotFound
		}

		return []NodeEdge{}, errors.New(pbNodesRequest.Error)
	}

	ret := make([]NodeEdge, len(pbNodesRequest.Nodes))

	for i, nPb := range pbNodesRequest.Nodes {
		ret[i], err = PbToNode(nPb)

		if err != nil {
			return ret, err
		}
	}

	return ret, nil
}

// RemoveDuplicateNodesIDParent removes duplicate nodes in list with the
// same ID and parent
func RemoveDuplicateNodesIDParent(nodes []NodeEdge) []NodeEdge {
	keys := make(map[string]bool)
	ret := []NodeEdge{}

	for _, n := range nodes {
		key := n.ID + n.Parent
		if _, ok := keys[key]; !ok {
			keys[key] = true
			ret = append(ret, n)
		}
	}

	return ret
}

// RemoveDuplicateNodesID removes duplicate nodes in list with the
// same ID (can have different parents)
func RemoveDuplicateNodesID(nodes []NodeEdge) []NodeEdge {
	keys := make(map[string]bool)
	ret := []NodeEdge{}

	for _, n := range nodes {
		key := n.ID
		if _, ok := keys[key]; !ok {
			keys[key] = true
			ret = append(ret, n)
		}
	}

	return ret
}
