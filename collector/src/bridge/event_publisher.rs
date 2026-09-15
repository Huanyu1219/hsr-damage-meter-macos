use super::protocol::Event;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PublishError {
    QueueFull,
    Closed,
}

/// M1 adapter boundary: copy an already-resolved event into a bounded queue.
/// Implementations must return immediately; no serialization, disk or socket I/O.
/// Sequence and timestamp are assigned by the single publisher worker.
pub trait EventPublisher: Send + Sync {
    fn try_publish(&self, event: Event) -> Result<(), PublishError>;
}
