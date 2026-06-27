type SectionTitleProps = {
  title: string;
  subtitle?: string;
};

export function SectionTitle({ title, subtitle }: SectionTitleProps) {
  return (
    <div className="mx-auto max-w-3xl text-center">
      <h2 className="font-heading text-3xl font-bold tracking-tight text-offWhite sm:text-5xl">
        {title}
      </h2>
      {subtitle ? <p className="mt-4 text-base text-silver">{subtitle}</p> : null}
    </div>
  );
}
