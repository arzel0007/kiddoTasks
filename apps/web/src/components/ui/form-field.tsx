import { Children, cloneElement, isValidElement, useId, type ReactElement, type ReactNode } from "react";

/** Form field wrapper that gives a single native control a real label, and
 * gives multi-control choices an accessible group name. */
export function FormField({
  label,
  children,
  error,
}: {
  label: string;
  children: ReactNode;
  error?: string | null;
}) {
  const id = useId();
  const child = Children.count(children) === 1 ? Children.only(children) : null;
  const isNativeControl =
    isValidElement(child) &&
    typeof child.type === "string" &&
    ["input", "select", "textarea"].includes(child.type);
  const errorId = `${id}-error`;
  const describedBy = error ? errorId : undefined;

  let control = children;
  if (isNativeControl && isValidElement(child)) {
    const props = child.props as {
      id?: string;
      "aria-describedby"?: string;
      "aria-invalid"?: boolean;
    };
    const existingDescribedBy = props["aria-describedby"];
    control = cloneElement(child as ReactElement<typeof props>, {
      id,
      "aria-invalid": error ? true : props["aria-invalid"],
      "aria-describedby": [existingDescribedBy, describedBy].filter(Boolean).join(" ") || undefined,
    });
  }

  return (
    <div>
      <label className="field-label" htmlFor={isNativeControl ? id : undefined} id={`${id}-label`}>
        {label}
      </label>
      {isNativeControl
        ? control
        : <div role="group" aria-labelledby={`${id}-label`} aria-describedby={describedBy}>{children}</div>}
      {error ? <p id={errorId} className="field-error" role="alert">{error}</p> : null}
    </div>
  );
}
