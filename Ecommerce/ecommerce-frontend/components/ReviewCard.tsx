type ReviewCardProps = {
  name: string;
  rating: number;
  title: string;
  body: string;
  verified?: boolean;
  photos?: string[];
  createdAt?: string;
};

export function ReviewCard({ name, rating, title, body, verified = false, photos = [], createdAt }: ReviewCardProps) {
  return (
    <article className="card p-5">
      <div className="flex items-center justify-between gap-2">
        <h3 className="font-semibold">{name}</h3>
        <div className="text-right">
          <span className="text-sm text-brand">{rating}/5</span>
          {verified && <p className="text-xs text-emerald-600">Verified purchase</p>}
        </div>
      </div>
      <p className="mt-3 font-medium text-slate-900">{title}</p>
      <p className="mt-2 text-sm text-slate-600">{body}</p>
      {photos.length > 0 && (
        <div className="mt-3 grid grid-cols-3 gap-2">
          {photos.slice(0, 3).map((photo, index) => (
            <img key={`${photo}-${index}`} src={photo} alt={`Review photo ${index + 1}`} className="h-20 w-full rounded-lg object-cover" />
          ))}
        </div>
      )}
      {createdAt && <p className="mt-3 text-xs text-slate-400">{new Date(createdAt).toLocaleDateString()}</p>}
    </article>
  );
}
